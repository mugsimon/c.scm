;; (define var (lambda requireds rest body))
;; (define var expr)
;; (begin ...)
;; (fun ...)
(define (c.scm:c6normalize x)
     (if (pair? x)
         (case (car x)
           ((define)
            (let ((form (caddr x)))
              (if (and (pair? form)
                       (eq? (car form) 'lambda))
                  (c.scm:c6normalize-function (car x) ;; define
                                               (cadr x) ;; name
                                               (caddr x)) ;; (lambda required rest body)
                  `(,(car x) ,(cadr x) ,(c.scm:c6normalize-expr form)))))
           ((begin)
            `(begin ,@(map c.scm:c6normalize (cdr x))))
           (else
            (c.scm:c6normalize-expr x)))
         (c.scm:c6normalize-expr x)))

(define (c.scm:c6normalize-function first name lambda-expr)
  (let ((x (c6lam (cdr lambda-expr))))
    (list first name (cons 'lambda x))))

;; form->expr
(define (c.scm:c6normalize-expr form)
  (c6expr form))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (c6expr form)
  (cond ((c.scm:symbol? form)
         (c6vref form))
        ((c.scm:pair? form)
         (let ((fun (car form))
               (args (cdr form)))
           (cond ((c.scm:symbol? fun)
                  (case fun
                    ((if) (c6if args))
                    ((and) (c6and args))
                    ((or) (c6or args))
                    ((begin) (c6begin args))
                    ((lambda) (c6lambda args))
                    ((delay) (c6delay args)) ;; (delay args)
                    ((let) (c6let args)) 
                    ((let*) (c6let* args))
                    ((letrec) (c6letrec args))
                    ((set!) (c6set! args)) ;;
                    ((quote) (c6quote args))
                    (else
                     (c6symbol-fun fun args))))
                 (else
                  `(,(c6expr fun) ,@(c6args (car args)))))))
        (else
         form)))

(define (c6vref name)
  (if (c.scm:var? name)
      (var-name name)
      name))

(define (c6if args)
  `(if ,(c6expr (car args))
       ,(c6expr (cadr args))
       ,(c6expr (caddr args))))

(define (c6and args)
  `(and ,@(c6args (car args))))

(define (c6or args)
  `(or ,@(c6args (car args))))

(define (c6begin args)
  `(begin ,@(c6map c6expr args)))

(define (c6lambda args)
  (let ((requireds (cadr args))
        (rest (caddr args))
        (body (cadddr args)))
    (let ((params (cond ((and (null? requireds)
                              (null? rest))
                         '())
                        ((null? requireds)
                         (var-name rest))
                        ((null? rest)
                         (map var-name requireds))
                        (else
                         (let ((req (map var-name requireds)))
                           (let loop ((res req))
                             (cond ((null? (cdr res))
                                    (set-cdr! res (var-name rest))
                                    req)
                                   (else
                                    (loop (cdr res))))))))))
      `(lambda ,params ,(c6expr body)))))

(define (c6lam args)
  (let ((requireds (car args))
        (rest (cadr args))
        (body (caddr args)))
    (let ((params (cond ((and (null? requireds)
                              (null? rest))
                         '())
                        ((null? requireds)
                         (var-name rest))
                        ((null? rest)
                         (map var-name requireds))
                        (else
                         (let ((req (map var-name requireds)))
                           (let loop ((res req))
                             (cond ((null? (cdr res))
                                    (set-cdr! res (var-name rest))
                                    req)
                                   (else
                                    (loop (cdr res))))))))))
      (list params (c6expr body)))))

(define (c6let form)
  (if (c.scm:var? (car form))
      (c6named-let form)
      (let loop ((defs (car form))
                 (ndefs '()))
        (cond ((null? defs)
               `(let ,(reverse ndefs) ,(c6expr (cadr form))))
              (else
               (loop (cdr defs)
                     (cons (c6let-def (car defs))
                           ndefs)))))))

(define (c6let-def def)
  (let ((var (car def))
        (expr (cdr def)))
    (if (var-local-fun var)
        (list (var-name var) `(lambda ,@(c6lam expr)))
        (list (var-name var) (c6expr expr)))))

(define (c6let* form)
  (let loop ((defs (car form))
             (ndefs '()))
    (cond ((null? defs)
           `(let* ,(reverse ndefs) ,(c6expr (cadr form))))
          (else
               (loop (cdr defs)
                     (cons (c6let-def (car defs))
                           ndefs))))))

(define (c6letrec form)
  (let loop ((defs (car form))
             (ndefs '()))
    (cond ((null? defs)
           `(letrec ,(reverse ndefs) ,(c6expr (cadr x))))
          (else
           (loop (cdr defs)
                 (cons (c6letrec-def (car defs))
                       ndefs))))))

(define (c6letrec-def def)
  (let ((var (car def))
        (expr (cadr def)))
    (if (var-local-fun var)
        (list (var-name var) `(lambda ,@(c6lam expr)))
        (list (var-name var) (c6expr expr)))))

(define (c6set! args)
  `(set! ,(c6expr (car args)) ,(c6expr (cadr args))))

(define (c6quote args)
  `(quote ,args))

(define (c6symbol-fun name args)
  (cond ((c.scm:var? name)
         `(,(var-name name) ,@(c6args (car args))))
        (else
         `(,name ,@(c6args (car args))))))

(define (c6args forms)
  (if (null? forms)
      '()
      (cons (c6expr (car forms))
            (c6args (cdr forms)))))
