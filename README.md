# http-get-cache

http-get-cache is a Common Lisp library based on the Drakma HTTP
client for caching HTTP GET responses.

http-get-cache depends on [Drakma](http://www.weitz.de/drakma/)
and
[Bordeaux Threads](https://common-lisp.net/project/bordeaux-threads/).

http-get-cache is being developed
with [SBCL](http://sbcl.org/), [CCL](http://ccl.clozure.com/),
and [LispWorks](http://www.lispworks.com/) on OS X.  http-get-cache is
being deployed with SBCL on FreeBSD/AMD64 and Linux/AMD64.


### Installation

```lisp
(ql:quickload "http-get-cache")
```

### Example

```lisp
(defvar *cache* (http-get-cache:make-cache 60))

(http-get-cache:http-get "http://planet.lisp.org/" *cache*)

#S(HTTP-GET-CACHE:RESPONSE
   :STATUS-CODE 200
   :HEADERS ((:SERVER . "nginx/1.9.0")
             (:DATE . "Thu, 16 Mar 2017 04:56:47 GMT")
             (:CONTENT-TYPE . "text/html") (:CONTENT-LENGTH . "128383")
             (:LAST-MODIFIED . "Thu, 16 Mar 2017 04:15:56 GMT")
             (:CONNECTION . "close") (:ETAG . "\"58ca117c-1f57f\"")
             (:ACCEPT-RANGES . "bytes"))
   :BODY "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">

<html>

<head>
<title>Planet Lisp</title>
...
</html>
"
   :TIMESTAMP 3698629006)

```

### License

http-get-cache is distributed under the MIT license. See LICENSE.
