Question 1
```text
FROM golang:1.18 AS builder

WORKDIR /app

COPY main.go .

RUN go mod init guestbook
RUN go mod tidy
RUN go build -o main main.go

FROM ubuntu:18.04

COPY --from=builder /app/main /app/guestbook
ADD public/index.html /app/public/index.html
ADD public/script.js /app/public/script.js
ADD public/style.css /app/public/style.css
ADD public/jquery.min.js /app/public/jquery.min.js

WORKDIR /app

CMD ["./guestbook"]
EXPOSE 3000
```

Question 2
```text
Listing images...
OK

Repository                                        Tag   Digest                                                                    Namespace
us.icr.io/<your sn labs namespace>/guestbook      v1    sha256:3f11796ae3a19be96311b58ebb0c4cee5c252e5c6aaf4ed37b0bde0550c47397  <your sn labs namespace>
```

Question 3
```text
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta content="text/html; charset=utf-8" http-equiv="Content-Type">
    <meta charset="utf-8">
    <meta content="width=device-width" name="viewport">
    <link href="style.css" rel="stylesheet">
    <title>Guestbook - v1</title>
  </head>
  <body>
    <div id="header">
      <h1>Guestbook - v1</h1>
    </div>

    <div id="guestbook-entries">
      <link href="https://afeld.github.io/emoji-css/emoji.css" rel="stylesheet">
      <p>Waiting for database connection... <i class='em em-boat'></i></p>
      
    </div>

    <div>
      <form id="guestbook-form">
        <input autocomplete="off" id="guestbook-entry-content" type="text">
        <a href="#" id="guestbook-submit">Submit</a>
      </form>
    </div>

    <div>
      <p><h2 id="guestbook-host-address"></h2></p>
      <p><a href="env">/env</a>
      <a href="info">/info</a></p>
    </div>
    <script src="jquery.min.js"></script>
    <script src="script.js"></script>
  </body>
</html>
```

Question 4
```text
NAME        REFERENCE              TARGETS             MINPODS   MAXPODS   REPLICAS   AGE
guestbook   Deployment/guestbook   cpu: <unknown>/5%   1         10        0          0s
```

Question 5
```text
NAME        REFERENCE              TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
guestbook   Deployment/guestbook   cpu: 205%/5%   1         10        4          33s
```

Question 6
```text
The push refers to repository [us.icr.io/<your sn labs namespace>/guestbook]
bfc26d3f02a6: Waiting
4f4fb700ef54: Waiting
7c457f213c76: Waiting
541fd7affd09: Waiting
b5e65af529df: Waiting
69a9f9ea60b4: Waiting
2f9d0c5ebb0a: Waiting
19c1e3a048ae: Waiting
2f9d0c5ebb0a: Waiting
19c1e3a048ae: Waiting
bfc26d3f02a6: Waiting
4f4fb700ef54: Waiting
7c457f213c76: Waiting
541fd7affd09: Waiting
b5e65af529df: Waiting
69a9f9ea60b4: Waiting
69a9f9ea60b4: Waiting
2f9d0c5ebb0a: Waiting
19c1e3a048ae: Waiting
bfc26d3f02a6: Waiting
4f4fb700ef54: Waiting
7c457f213c76: Waiting
541fd7affd09: Waiting
b5e65af529df: Waiting
2f9d0c5ebb0a: Waiting
19c1e3a048ae: Waiting
bfc26d3f02a6: Waiting
4f4fb700ef54: Waiting
7c457f213c76: Waiting
541fd7affd09: Waiting
b5e65af529df: Waiting
69a9f9ea60b4: Waiting
4f4fb700ef54: Waiting
7c457f213c76: Waiting
541fd7affd09: Waiting
b5e65af529df: Waiting
69a9f9ea60b4: Waiting
2f9d0c5ebb0a: Waiting
19c1e3a048ae: Waiting
bfc26d3f02a6: Waiting
19c1e3a048ae: Waiting
bfc26d3f02a6: Waiting
4f4fb700ef54: Waiting
7c457f213c76: Waiting
541fd7affd09: Waiting
b5e65af529df: Waiting
69a9f9ea60b4: Waiting
2f9d0c5ebb0a: Waiting
4f4fb700ef54: Layer already exists
7c457f213c76: Layer already exists
541fd7affd09: Layer already exists
b5e65af529df: Layer already exists
69a9f9ea60b4: Layer already exists
2f9d0c5ebb0a: Layer already exists
19c1e3a048ae: Layer already exists
bfc26d3f02a6: Already exists
v2: digest: sha256:01a030210282b502c1c783f959c0d640c505e928f496493728efdbf9f2be200d size: 856
```

Question 7
```text
Deployment Configured
```

Question 8
```text
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta content="text/html; charset=utf-8" http-equiv="Content-Type">
    <meta charset="utf-8">
    <meta content="width=device-width" name="viewport">
    <link href="style.css" rel="stylesheet">
    <title>Guestbook - v2</title>
  </head>
  <body>
    <div id="header">
      <h1>Guestbook - v2</h1>
    </div>

    <div id="guestbook-entries">
      <link href="https://afeld.github.io/emoji-css/emoji.css" rel="stylesheet">
      <p>Waiting for database connection... <i class='em em-boat'></i></p>
      
    </div>

    <div>
      <form id="guestbook-form">
        <input autocomplete="off" id="guestbook-entry-content" type="text">
        <a href="#" id="guestbook-submit">Submit</a>
      </form>
    </div>

    <div>
      <p><h2 id="guestbook-host-address"></h2></p>
      <p><a href="env">/env</a>
      <a href="info">/info</a></p>
    </div>
    <script src="jquery.min.js"></script>
    <script src="script.js"></script>
  </body>
</html>
```

Question 9
```text
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
```

Question 10
```text
NAME                   DESIRED   CURRENT   READY   AGE
guestbook-659c567bc5   0         0         0       66s
guestbook-7c99d998bb   8         8         8       3m10s
```

