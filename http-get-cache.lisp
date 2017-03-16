;;;; http-get-cache.lisp

;;; The MIT License (MIT)
;;;
;;; Copyright (c) 2013 Michael J. Forster
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a copy
;;; of this software and associated documentation files (the "Software"), to deal
;;; in the Software without restriction, including without limitation the rights
;;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;;; copies of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included in all
;;; copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;;; SOFTWARE.

(in-package "HTTP-GET-CACHE")

(defconstant +http-ok+ 200)

(defconstant +http-not-modified+ 304)

(defstruct response
  "A RESPONSE ia an object that stores the status code, headers, and
body of an HTTP response, as well as the timestamp at which the
response was received."
  status-code
  headers
  body
  timestamp)

(defun response-fresh-p (response ttl now)
  (> ttl (- now (response-timestamp response))))

(defstruct (cache (:constructor %make-cache))
  "A CACHE is an object that stores successful responses to HTTP GET
requests. A response is stored until its TTL--time to live, in
seconds--expires."
  (responses (make-hash-table :test #'equal))
  (mutex (bt:make-lock "http-get-cache"))
  ttl)

(defun make-cache (&optional (ttl 300))
  "Create and return a CACHE with the optionally supplied TTL. TTL
defaults to 300."
  (%make-cache :ttl ttl))

(defun uri-key (uri)
  (string-downcase (puri:render-uri uri nil)))

(define-condition http-get-error (error)
  ()
  (:documentation "Superclass for all errors signaled by HTTP-GET."))

(define-condition http-get-not-found (http-get-error)
  ((uri :initarg :uri :reader http-get-not-found-uri))
  (:documentation "Signalled by HTTP-GET when a RESPONSE for the URI
is neither cached nor available via an HTTP GET request."))

(defun http-get-not-found (uri)
  "Signal an error of type HTTP-GET-NOT-FOUND for the URI."
  (error 'http-get-not-found :uri uri))

(defun http-get (uri cache &key (if-http-get-not-found :error))
  "Return the RESPONSE for the supplied URI. If a fresh RESPONSE for
the URI exists in the CACHE then return that RESPONSE. If a stale
RESPONSE for the URI exists in the CACHE then attempt to validate the
RESPONSE with the origin server using the \"If-None-Match\" request
header and the \"Etag\" header of the RESPONSE and, if successful,
update the headers of the cached RESPONSE and return it. If no
RESPONSE for the URI exists in the CACHE then make an HTTP GET request
for the URI and, if successful, cache and return the RESPONSE;
otherwise, signal an error of type HTTP-GET-NOT-FOUND>

If URI is neither a PURI:URI nor a STRING, signal an error of type
TYPE-ERROR. If CACHE is not a CACHE, signal an error of type
TYPE-ERROR.

Unlike an RFC 7234 compliant HTTP cache, HTTP-GET-CACHE expires a
stored RESPONSE according to the time the RESPONSE was received and
the CACHE TTL. HTTP-GET-CACHE ignores the \"Expires\" header field and
the \"max-age\" cache directive of the HTTP request and response."
  (check-type uri (or string puri:uri))
  (check-type cache cache)
  (flet ((http-get-aux (&optional response)
           (multiple-value-bind (body status-code headers uri stream must-close reason-phrase)
               (drakma:http-request uri
                                    :additional-headers (list (cons "If-None-Match"
                                                                    (if response
                                                                        (cdr (assoc :etag (response-headers response)))
                                                                        nil))))
             (declare (ignore uri stream must-close reason-phrase))
             (cond ((= status-code +http-ok+)
                    (let ((response (make-response :status-code status-code
                                                   :headers headers
                                                   :body body
                                                   :timestamp (get-universal-time))))
                      (setf (gethash (uri-key uri) (cache-responses cache))
                            response)
                      response))
                   ((and (not (null response))
                         (= status-code +http-not-modified+))
                    ;; See Sections 4.3.2 and 4.3.4 of RFC 7234.
                    (setf (response-headers response) headers
                          (response-timestamp response) (get-universal-time))
                    response)
                   ((eq if-http-get-not-found :error)
                    (http-get-not-found uri))
                   (t
                    nil)))))
    (bt:with-lock-held ((cache-mutex cache))
      (multiple-value-bind (response present-p)
          (gethash (uri-key uri) (cache-responses cache))
        (if present-p
            (if (response-fresh-p response (cache-ttl cache) (get-universal-time))
                response
                ;; TODO: by reusing this w/ optional args, we tangle validation and freshness (Expires | max-age)
                (http-get-aux response))
            (http-get-aux))))))
