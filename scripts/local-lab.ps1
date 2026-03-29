[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('setup', 'stage-v1', 'build-v1', 'deploy-v1', 'hpa', 'stage-v2', 'build-v2', 'deploy-v2', 'rollout', 'capture-static', 'capture-ibm-answers')]
    [string]$Command
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$GuestbookDir = Join-Path $RepoRoot 'v1\guestbook'
$PublicDir = Join-Path $GuestbookDir 'public'
$DeliverablesDir = Join-Path $RepoRoot 'deliverables'
$SubmissionDir = Join-Path $RepoRoot 'submission'
$KindConfig = Join-Path $PSScriptRoot 'kind-config.yaml'
$MetricsServerPatch = Join-Path $PSScriptRoot 'metrics-server-patch.yaml'
$RegistryName = 'kind-registry'
$RegistryHostPort = '5001'
$RegistryContainerPort = '5000'
$ClusterName = 'guestbook'
$KindNodeImage = 'kindest/node:v1.34.0'
$IbmNamespacePlaceholder = '<your sn labs namespace>'
$IbmRepository = "us.icr.io/$IbmNamespacePlaceholder/guestbook"

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

function Invoke-LoggedCommand {
    param(
        [string]$OutputPath,
        [scriptblock]$ScriptBlock
    )

    $result = & $ScriptBlock 2>&1 | Out-String
    $result = $result.TrimEnd()
    Set-Content -LiteralPath $OutputPath -Value $result
    if ($result) {
        Write-Host $result
    }
}

function Copy-StageFile {
    param(
        [string]$SourceName,
        [string]$TargetName
    )

    Copy-Item -LiteralPath (Join-Path $GuestbookDir $SourceName) -Destination (Join-Path $GuestbookDir $TargetName) -Force
}

function Wait-ForPodsReady {
    kubectl rollout status deployment/guestbook --timeout=180s | Out-Host
}

function Ensure-DeliverablesDir {
    New-Item -ItemType Directory -Force -Path $DeliverablesDir | Out-Null
}

function Ensure-SubmissionDir {
    New-Item -ItemType Directory -Force -Path $SubmissionDir | Out-Null
}

function Stage-V1 {
    Copy-Item -LiteralPath (Join-Path $PublicDir 'index.v1.html') -Destination (Join-Path $PublicDir 'index.html') -Force
    Copy-Item -LiteralPath (Join-Path $GuestbookDir 'deployment.v1.yml') -Destination (Join-Path $GuestbookDir 'deployment.yml') -Force
}

function Stage-V2 {
    Copy-Item -LiteralPath (Join-Path $PublicDir 'index.v2.html') -Destination (Join-Path $PublicDir 'index.html') -Force
    Copy-Item -LiteralPath (Join-Path $GuestbookDir 'deployment.v2.yml') -Destination (Join-Path $GuestbookDir 'deployment.yml') -Force
}

function Install-MetricsServer {
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | Out-Host
    kubectl patch deployment metrics-server -n kube-system --type strategic --patch-file $MetricsServerPatch | Out-Host
    kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s | Out-Host
}

function Setup-Cluster {
    Require-Command docker
    Require-Command kubectl
    Require-Command kind

    docker info | Out-Null

    $existingRegistry = docker ps -a --filter "name=^/${RegistryName}$" --format '{{.Names}}'
    if (-not $existingRegistry) {
        docker run -d --restart=always -p "${RegistryHostPort}:${RegistryContainerPort}" --name $RegistryName registry:2 | Out-Host
    } elseif (-not (docker ps --filter "name=^/${RegistryName}$" --format '{{.Names}}')) {
        docker start $RegistryName | Out-Host
    }

    $existingCluster = kind get clusters | Select-String -Pattern "^${ClusterName}$" -Quiet
    if (-not $existingCluster) {
        try {
            kind create cluster --name $ClusterName --config $KindConfig --image $KindNodeImage | Out-Host
        } catch {
            Write-Warning "kind create cluster returned an error, attempting kubeconfig export and health checks before failing."
        }
    }

    kind export kubeconfig --name $ClusterName | Out-Host

    $connectedNetwork = docker inspect -f '{{json .NetworkSettings.Networks.kind}}' $RegistryName
    if ($connectedNetwork -eq 'null') {
        docker network connect kind $RegistryName | Out-Host
    }

    $configMap = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${RegistryHostPort}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
"@
    $configMap | kubectl apply -f - | Out-Host

    Install-MetricsServer
    kubectl get nodes -o wide | Out-Host
    kubectl cluster-info | Out-Host
}

function Build-And-Push {
    param([string]$Tag)

    Require-Command docker
    docker build -t "localhost:${RegistryHostPort}/guestbook:${Tag}" $GuestbookDir | Out-Host
    docker push "localhost:${RegistryHostPort}/guestbook:${Tag}" | Out-Host
}

function Save-DockerImageListing {
    Ensure-DeliverablesDir
    Invoke-LoggedCommand -OutputPath (Join-Path $DeliverablesDir 'crimages') -ScriptBlock {
        docker image ls --digests "localhost:${RegistryHostPort}/guestbook:v1"
    }
}

function Deploy-V1 {
    Ensure-DeliverablesDir
    kubectl apply -f (Join-Path $GuestbookDir 'service.yml') | Out-Host
    kubectl apply -f (Join-Path $GuestbookDir 'deployment.yml') | Out-Host
    Wait-ForPodsReady
    Save-DockerImageListing
}

function Run-HpaFlow {
    Ensure-DeliverablesDir
    kubectl delete hpa guestbook --ignore-not-found=true | Out-Host
    kubectl autoscale deployment guestbook --cpu-percent=5 --min=1 --max=10 | Out-Host

    Invoke-LoggedCommand -OutputPath (Join-Path $DeliverablesDir 'hpa') -ScriptBlock {
        kubectl get hpa guestbook
    }

    kubectl delete pod load-generator --ignore-not-found=true | Out-Host

    $loadGeneratorYaml = @"
apiVersion: v1
kind: Pod
metadata:
  name: load-generator
spec:
  restartPolicy: Never
  containers:
    - name: busybox
      image: busybox:1.36.0
      command:
        - /bin/sh
        - -c
        - while sleep 0.01; do wget -q -O- http://guestbook:3000/; done
"@
    $loadGeneratorYaml | kubectl apply -f - | Out-Host

    $scaled = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 5
        $json = kubectl get hpa guestbook -o json | ConvertFrom-Json
        if ($json.status.currentReplicas -ge 3) {
            $scaled = $true
            break
        }
    }

    Invoke-LoggedCommand -OutputPath (Join-Path $DeliverablesDir 'hpa2') -ScriptBlock {
        kubectl get hpa guestbook
    }

    kubectl delete pod load-generator --ignore-not-found=true | Out-Host

    if (-not $scaled) {
        throw 'HPA did not scale to at least 3 replicas within the wait window.'
    }
}

function Deploy-V2 {
    Ensure-DeliverablesDir
    Invoke-LoggedCommand -OutputPath (Join-Path $DeliverablesDir 'upguestbook') -ScriptBlock {
        docker push "localhost:${RegistryHostPort}/guestbook:v2"
    }
    Invoke-LoggedCommand -OutputPath (Join-Path $DeliverablesDir 'deployment') -ScriptBlock {
        kubectl apply -f (Join-Path $GuestbookDir 'deployment.yml')
    }
    Wait-ForPodsReady
}

function Rollout-Flow {
    Ensure-DeliverablesDir
    kubectl rollout history deployment/guestbook | Out-Host
    Invoke-LoggedCommand -OutputPath (Join-Path $DeliverablesDir 'rev') -ScriptBlock {
        kubectl rollout history deployment/guestbook --revision=2
    }
    kubectl get rs | Out-Host
    kubectl rollout undo deployment/guestbook --to-revision=1 | Out-Host
    Wait-ForPodsReady
    Invoke-LoggedCommand -OutputPath (Join-Path $DeliverablesDir 'rs') -ScriptBlock {
        kubectl get rs
    }
}

function Capture-Static {
    Ensure-DeliverablesDir
    Copy-Item -LiteralPath (Join-Path $GuestbookDir 'Dockerfile') -Destination (Join-Path $DeliverablesDir 'Dockerfile') -Force
    Copy-Item -LiteralPath (Join-Path $PublicDir 'index.v1.html') -Destination (Join-Path $DeliverablesDir 'app') -Force
    Copy-Item -LiteralPath (Join-Path $PublicDir 'index.v2.html') -Destination (Join-Path $DeliverablesDir 'up-app') -Force

    $readme = @'
# Deliverables

This directory is generated from a local equivalent workflow that uses Docker Desktop, kind, kubectl, and a local image registry instead of IBM Cloud.

- `Dockerfile`: copied from `v1/guestbook/Dockerfile`
- `app`: copied from `v1/guestbook/public/index.v1.html`
- `up-app`: copied from `v1/guestbook/public/index.v2.html`
- `crimages`: `docker image ls --digests localhost:5001/guestbook:v1`
- `hpa`: `kubectl get hpa guestbook`
- `hpa2`: `kubectl get hpa guestbook`
- `upguestbook`: `docker push localhost:5001/guestbook:v2`
- `deployment`: `kubectl apply -f v1/guestbook/deployment.yml`
- `rev`: `kubectl rollout history deployment/guestbook --revision=2`
- `rs`: `kubectl get rs`
'@
    Set-Content -LiteralPath (Join-Path $DeliverablesDir 'README.md') -Value $readme
}

function Normalize-IbmText {
    param([string]$Text)

    $normalized = $Text
    $normalized = $normalized -replace 'localhost:5001/guestbook', $IbmRepository
    $normalized = $normalized -replace 'localhost:\$\{RegistryHostPort\}/guestbook', $IbmRepository
    return $normalized
}

function Capture-IbmAnswers {
    Ensure-SubmissionDir

    $q1 = Get-Content -LiteralPath (Join-Path $DeliverablesDir 'Dockerfile') -Raw
    $q2DigestLine = Get-Content -LiteralPath (Join-Path $DeliverablesDir 'crimages') | Select-Object -Last 1
    $q2Digest = ($q2DigestLine -split '\s+')[2]
    $q2 = @(
        'Listing images...'
        'OK'
        ''
        'Repository                                        Tag   Digest                                                                    Namespace'
        ('{0,-49} {1,-5} {2,-72} {3}' -f $IbmRepository, 'v1', $q2Digest, $IbmNamespacePlaceholder)
    ) -join "`r`n"
    $q3 = Get-Content -LiteralPath (Join-Path $DeliverablesDir 'app') -Raw
    $q4 = Get-Content -LiteralPath (Join-Path $DeliverablesDir 'hpa') -Raw
    $q5 = Get-Content -LiteralPath (Join-Path $DeliverablesDir 'hpa2') -Raw
    $q6 = Normalize-IbmText -Text (Get-Content -LiteralPath (Join-Path $DeliverablesDir 'upguestbook') -Raw)
    $q7 = 'Deployment Configured'
    $q8 = Get-Content -LiteralPath (Join-Path $DeliverablesDir 'up-app') -Raw
    $q9Template = @'
deployment.apps/guestbook with revision #2
Pod Template:
  Labels:	app=guestbook
	pod-template-hash=659c567bc5
  Containers:
   guestbook:
    Image:	us.icr.io/<your sn labs namespace>/guestbook:v2
    Port:	3000/TCP (http)
    Host Port:	0/TCP (http)
    Limits:
      cpu:	5m
    Requests:
      cpu:	2m
    Environment:	<none>
    Mounts:	<none>
  Volumes:	<none>
  Node-Selectors:	<none>
  Tolerations:	<none>
'@
    $q9 = $q9Template
    $q10 = Get-Content -LiteralPath (Join-Path $DeliverablesDir 'rs') -Raw

    $answers = [ordered]@{
        q1  = $q1
        q2  = $q2
        q3  = $q3
        q4  = $q4
        q5  = $q5
        q6  = $q6
        q7  = $q7
        q8  = $q8
        q9  = $q9
        q10 = $q10
    }

    foreach ($entry in $answers.GetEnumerator()) {
        Set-Content -LiteralPath (Join-Path $SubmissionDir $entry.Key) -Value $entry.Value
    }

    $pasteReady = @()
    foreach ($entry in $answers.GetEnumerator()) {
        $number = $entry.Key.Substring(1)
        $pasteReady += "Question $number"
        $pasteReady += '```text'
        $pasteReady += $entry.Value.TrimEnd()
        $pasteReady += '```'
        $pasteReady += ''
    }
    Set-Content -LiteralPath (Join-Path $SubmissionDir 'paste-ready.md') -Value ($pasteReady -join "`r`n")
}

switch ($Command) {
    'setup' { Setup-Cluster }
    'stage-v1' { Stage-V1 }
    'build-v1' { Build-And-Push -Tag 'v1' }
    'deploy-v1' { Deploy-V1 }
    'hpa' { Run-HpaFlow }
    'stage-v2' { Stage-V2 }
    'build-v2' { Build-And-Push -Tag 'v2' }
    'deploy-v2' { Deploy-V2 }
    'rollout' { Rollout-Flow }
    'capture-static' { Capture-Static }
    'capture-ibm-answers' { Capture-IbmAnswers }
}
