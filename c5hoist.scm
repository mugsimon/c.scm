;;; 定義を受け取り、ホイスト可能なローカル関数をトップレベルへ移動する
;;; 受け取る定義はクローズ済み
;;; ホイストされたあとの関数を最初の要素とし、残りにホイストされた関数が続くリストを返す

;; (define var (lambda params body))
;; (define var expr)
(define (c5hoist x)
  (if (pair? x)
      (case (car x)
        ((define)
         (let ((first (car x))
               (name (cadr x))
               (form (caddr x)))
           (if (and (pair? form)
                    (eq? (car form) 'lambda))
               (c5def-func first
                           name
                           form)
               (c5def-expr first
                           name
                           form))))
        (else
         (error "CSCM:ERROR, c5hoist, not a definition" x)))
      (error "CSCM:ERROR, c5hoist, not a definition" x)))

(define (c5def-func first name lambda-expr)
  (let ((tmp *c5hoisted-funs*))
    (set! *c5hoisted-funs* '())
    (let ((x (c5expr lambda-expr)))
      (cons `(,first ,name ,x) *c5hoisted-funs*))
    (set! *c5hoisted-funs* tmp)))

(define (c5def-expr first name expr)
  (let ((tmp *c5hoisted-funs*))
    (set! *c5hoisted-funs* '())
    (let ((x (c5expr expr)))
      (cons `(,first ,name ,x) *c5hoisted-funs*))
    (set! *c5hoisted-funs* tmp)))

(define *c5hoisted-funs* '())
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (c5expr form)
  (cond ((cscm:pair? form)
         (let ((fun (car form))
               (args (cdr form)))
           (cond ((cscm:symbol? fun)
                  (case fun
                    ((if) (c5if args))
                    ((and) (c5and args))
                    ((or) (c5or args))
                    ((begin) (c5begin args))
                    ((lambda) (c5lambda args))
                    ((delay) (c5delay args))
                    ((let) (c5let args))
                    ((let*) (c5let args))
                    ((letrec) (c5letrec args))
                    ((set!) (c5set! args))
                    ((quote) (c5quote args))
                    (else
                     (c5symbol-fun fun args))))
                 (else
                  `(,(c5expr fun) ,@(c5args args))))))
        (else
         (case form
           ((#f) #f)
           ((#t) #t)
           ((()) '())
           (else
            form)))))

(define (c5if args)
  `(if ,(c5expr (car args))
       ,(c5expr (cadr args))
       ,(c5expr (caddr args))))

(define (c5and args)
  `(and ,@(map c5expr args)))

(define (c5or args)
  `(or ,@(map c5expr args)))

(define (c5begin args)
  `(begin ,@(map c5expr args)))

(define (c5lambda args)
  (let ((params (car args))
        (body (cadr args)))
    (list 'lambda params (c5expr body))))

(define (c5let args)
  (let loop ((defs (car args))
             (cdefs '()))
    (cond ((null? defs)
           (if (null? cdefs)
               (c5expr (cadr args))
               `(let ,(reverse cdefs) ,(c5expr (cadr args)))))
          (else
           (let ((def (car defs)))
             (if (var-local-fun (car def))
                 (begin (c5hoist-fun def)
                        (loop (cdr defs)
                              cdefs))
                 (loop (cdr defs)
                       (cons (list (car def)
                                   (c5expr (cadr def)))
                             cdefs))))))))

(define (c5hoist-fun def)
  (set! *c5hoisted-funs* (cons (cons 'define def) *c5hoisted-funs*)))

(define (c5letrec args)
  (let loop ((defs (car args))
             (cdefs '()))
    (cond ((null? defs)
           (if (null? cdefs)
               (c5expr (cadr args))
               `(letrec ,(reverse cdefs) ,(c5expr (cadr args)))))
          (else
           (let ((var (caar defs))
                 (form (cadar defs)))
             (if (var-local-fun var)
                 (begin (c5hoist-fun (car defs))
                        (loop (cdr defs)
                              cdefs))
                 (loop (cdr defs)
                       (cons (list var
                                   (c5expr form))
                             cdefs))))))))

(define (c5set! args)
  (let ((var (car args))
        (exp (cadr args)))
    `(set! ,var ,(c5expr exp))))

(define (c5quote args)
  `(quote ,@args))

(define (c5symbol-fun fun args)
  `(,fun ,@(c5args args)))

(define (c5args args)
  (if (null? args)
      '()
      (cons (c5expr (car args))
            (c5args (cdr args)))))
