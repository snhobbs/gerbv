; gEDA - GNU Electronic Design Automation
; gerb-ps.scm 
; Copyright (C) 2000-2001 Stefan Petersen (spe@stacken.kth.se)
;
; $Id$
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA


(define *last-aperture-type* '())
(define *last-x* '())
(define *last-y* '())

(define (net:get-start net)
  (list-ref net 0))
(define (net:get-stop net)
  (list-ref net 1))
(define (net:get-arc-start net)
  (list-ref net 2))
(define (net:get-aperture net)
  (list-ref net 3))
(define (net:get-interpolation net)
  (list-ref net 4))

(define (aperture:get-number aperture)
  (list-ref aperture 0))
(define (aperture:get-type aperture)
  (list-ref aperture 1))
(define (aperture:get-sizes aperture)
  (list-tail aperture 2))

(define (ps-preamble info port)
  (display "%!\n" port)
  (display "%generated by gerbv\n\n" port)
  (display "/inch {72 mul} def\n" port)
  (display "/mm {2.54 div} def\n" port)
  (newline port)
  (display "1.5 inch 3 inch translate\n" port)
  (newline port)
  (if (equal? (assoc-ref info 'polarity) 'positive)
      (begin
	(display "/Black {0 setgray} def\n" port)
	(display "/White {1 setgray} def\n" port))
      (begin
	(display "/Black {1 setgray} def % Polarity reversed\n" port)
	(display "/White {0 setgray} def\n" port)))
  (newline port)
  (display "/circle { % x y id od\n" port)
  (display "	gsave\n" port)
  (display "	3 index 3 index moveto\n" port)
  (display "	3 index 3 index 3 2 roll % Fix arguments\n" port)
  (display "	2 div % d given, need r\n" port)
  (display "	0 360 arc Black fill % outer\n" port)
  (display "	2 div % d given, need r\n" port)
  (display "	0 360 arc White fill %inner\n" port)
  (display "grestore\n" port)
  (display "} def\n" port)
  (newline port)
  (display "/rectangle { % x y xl yl\n" port)
  (display "	gsave\n" port)
  (display "	newpath\n" port)
  (display "	1 setlinewidth\n" port)
  (display "	3 index 2 index 2 div sub\n" port)
  (display "	3 index 2 index 2 div add moveto\n" port)
  (display "	1 index 0 rlineto\n" port) ; ->
  (display "	dup -1 mul 0 exch rlineto\n" port) ; \!/
  (display "	1 index -1 mul 0 rlineto\n" port) ; <-
  (display "	dup 0 exch rlineto\n" port) ; /!\
  (display "	pop pop pop pop closepath  Black fill\n" port)
  (display "	grestore\n" port)
  (display "} def\n" port)
  (newline port)
  ; Make box for inverted print outs. Make it little bigger than limits.
  (display "gsave 72 setlinewidth newpath\n" port)
  (let ((min-x (number->string (- (assoc-ref info 'min-x) 200)))
	(min-y (number->string (- (assoc-ref info 'min-y) 200)))
	(max-x (number->string (+ (assoc-ref info 'max-x) 200)))
	(max-y (number->string (+ (assoc-ref info 'max-y) 200)))
	(unit (assoc-ref info 'unit)))
    (display (string-append max-x " " unit " ") port)
    (display (string-append max-y " " unit " moveto\n") port)
    (display (string-append max-x " " unit " ") port)
    (display (string-append min-y " " unit " lineto\n") port)
    (display (string-append min-x " " unit " ") port)
    (display (string-append min-y " " unit " lineto\n") port)
    (display (string-append min-x " " unit " ") port)
    (display (string-append max-y " " unit " lineto\n") port))
  (display "closepath White fill grestore\n" port)
  (newline port))

(define (print-ps-element element aperture format info port)
  (let* ((x (car (net:get-stop element)))
	 (y (cdr (net:get-stop element)))
	 (aperture-type (car (net:get-aperture element)))
	 (aperture-state (cdr (net:get-aperture element)))
	 (unit (assoc-ref info 'unit)))
    (cond ((eq? aperture-state 'exposure-off)
	   (handle-line-aperture aperture-type aperture unit port)
	   (print-position x y unit port)
	   (display " moveto\n" port))
	  ((eq? aperture-state 'exposure-on)
	   (handle-line-aperture aperture-type aperture unit port)
	   (print-position x y unit port)
	   (display " lineto\n" port))
	  ((eq? aperture-state 'exposure-flash)
	   (print-position x y unit port)
	   (display " " port)
	   (print-flash-aperture aperture-type aperture unit port)))
    (set! *last-x* x)
    (set! *last-y* y)))

(define (print-position x y unit port)
  (display x port) ; X axis
  (display " " port)
  (display unit port)
  (display " " port)
  (display y port) ; Y axis
  (display " " port)
  (display unit port))

(define (handle-line-aperture aperture-type aperture unit port)
  (cond ((null? *last-aperture-type*) ; First time
	 (set! *last-aperture-type* aperture-type)
	 (display "0 " port)
	 (display unit port)
	 (display " setlinewidth\n" port))
	((not (eq? *last-aperture-type* aperture-type)) ; new aperture
	 (display "stroke\n" port)
	 (display *last-x* port) ; X Axis
	 (display " " port)
	 (display unit port)
	 (display " " port)
	 (display *last-y* port)
	 (display " " port)
	 (display unit port)
	 (display " moveto\n" port)
	 (display (get-aperture-size aperture-type aperture) port)
	 (display " " port)
	 (display unit port)
	 (display " setlinewidth\n" port)
	 (set! *last-aperture-type* aperture-type))))

  
(define (print-flash-aperture aperture-type aperture unit port)
  (let* ((aperture-description (assv aperture-type aperture))
	 (type (aperture:get-type aperture-description))
	 (sizes (aperture:get-sizes aperture-description)))
    (case (length sizes)
      ((1) 
       (display " 0 " port)
       (display (car sizes) port)
       (display " " port)
       (display unit port)
       (display " " port))
      ((2)
       (display (car sizes) port)
       (display " " port)
       (display unit port)
       (display " " port)
       (display (cadr sizes) port)
       (display " " port)
       (display unit port)
       (display " " port)))
    (case type
      ((circle)
       (display " circle" port))
      ((rectangle)
       (display " rectangle  " port))
      ((oval)
       (display " rectangle % oval" port))
      ((polygon)
       (display " moveto % polygon" port))
      ((macro)
       (display " moveto % macro" port))
      (else 
       (display " moveto %unknown" port))))
  (newline port))

(define (get-aperture-size aperture-type aperture)
  (let ((aperture-desc (assv aperture-type aperture)))
    (if aperture-desc
	(car (aperture:get-sizes aperture-desc)))))


(define (generate-ps netlist aperture info format port)
  (ps-preamble info port)
  (for-each (lambda (element)
	      (print-ps-element element aperture format info port))
	    netlist)
  (display "stroke\nshowpage\n" port))

      
(define (main netlist aperture info format filename)
  (display "Warning! This backend is incomplete and known ")
  (display "to generate incorrect PostScript files\n")
  (let ((outfile (string-append filename ".ps")))
    (display (string-append "Output file will be " outfile "\n"))
    (call-with-output-file outfile
      (lambda (port) 
	(generate-ps (reverse netlist) aperture info format port)))))