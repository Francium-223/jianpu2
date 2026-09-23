\version "2.20.0"
#(set-global-staff-size 20)

% un-comment the next line to remove Lilypond tagline:
% \header { tagline="" }

% comment out the next line if you're debugging jianpu-ly
% (but best leave it un-commented in production, since
% the point-and-click locations won't go to the user input)
\pointAndClickOff

\paper {
  print-all-headers = ##t %% allow per-score headers

  % un-comment the next line for A5:
  % #(set-default-paper-size "a5" )

  % un-comment the next line for no page numbers:
  % print-page-number = ##f

  % un-comment the next 3 lines for a binding edge:
  % two-sided = ##t
  % inner-margin = 20\mm
  % outer-margin = 10\mm

  % un-comment the next line for a more space-saving header layout:
  % scoreTitleMarkup = \markup { \center-column { \fill-line { \magnify #1.5 { \bold { \fromproperty #'header:dedication } } \magnify #1.5 { \bold { \fromproperty #'header:title } } \fromproperty #'header:composer } \fill-line { \fromproperty #'header:instrument \fromproperty #'header:subtitle \smaller{\fromproperty #'header:subsubtitle } } } }
}

%% 2-dot and 3-dot articulations
#(append! default-script-alist
   (list
    `(two-dots
       . (
           (script-priority . -200)
           (stencil . ,ly:text-interface::print)
           (text . ,#{ \markup \override #'(font-encoding . latin1) \center-align \bold ":" #})
           (padding . 0.20)
           (avoid-slur . inside)
           (side-axis . ,Y)
           (direction . ,UP)))))
#(append! default-script-alist
   (list
    `(three-dots
       . (
           (script-priority . -200)
           (stencil . ,ly:text-interface::print)
           (text . ,#{ \markup \override #'(font-encoding . latin1) \center-align \bold "⋮" #})
           (padding . 0.30)
           (avoid-slur . inside)
           (side-axis . ,Y)
           (direction . ,UP)))))
"two-dots" =
#(make-articulation 'two-dots)

"three-dots" =
#(make-articulation 'three-dots)

\layout {
  \context {
    \Score
    scriptDefinitions = #default-script-alist
  }
}

note-mod =
#(define-music-function
     (text note)
     (markup? ly:music?)
   #{
     \tweak NoteHead.stencil #ly:text-interface::print
     \tweak NoteHead.text
        \markup \lower #0.5 \sans \bold #text
     \tweak Rest.stencil #ly:text-interface::print
     \tweak Rest.text
        \markup \lower #0.5 \sans \bold #text
     #note
   #})

#(define (jianpu-glissando grob)
   (let* ((left-note (ly:spanner-bound grob LEFT))
          (right-note (ly:spanner-bound grob RIGHT))
          (left-y (ly:grob-property left-note 'Y-offset 0))
          (right-y (ly:grob-property right-note 'Y-offset 0))
          (left-event (ly:grob-property left-note 'cause))
          (right-event (ly:grob-property right-note 'cause))
          (left-pitch (and (ly:stream-event? left-event)
                           (ly:event-property left-event 'pitch)))
          (right-pitch (and (ly:stream-event? right-event)
                            (ly:event-property right-event 'pitch))))
     (if (and left-pitch right-pitch)
         (let* ((left-y-off (if (ly:pitch<? left-pitch right-pitch) (- left-y 0.9) (if (ly:pitch<? right-pitch left-pitch) (+ left-y 1.5) left-y)))
                (right-y-off (if (ly:pitch<? left-pitch right-pitch) (+ right-y 0.9) (if (ly:pitch<? right-pitch left-pitch) (- right-y 1.5) right-y)))
                (bd (ly:grob-property grob 'bound-details))
                (left-bd (list-copy (assoc-get 'left bd '())))
                (right-bd (list-copy (assoc-get 'right bd '())))
                (new-left-bd (assoc-set! left-bd 'Y left-y-off))
                (new-right-bd (assoc-set! right-bd 'Y right-y-off))
                (new-bd (list (cons 'left new-left-bd) (cons 'right new-right-bd))))
           (ly:grob-set-property! grob 'bound-details new-bd)))))
#(define (flip-beams grob)
   (ly:grob-set-property!
    grob 'stencil
    (ly:stencil-translate
     (let* ((stl (ly:grob-property grob 'stencil))
            (centered-stl (ly:stencil-aligned-to stl Y DOWN)))
       (ly:stencil-translate-axis
        (ly:stencil-scale centered-stl 1 -1)
        (* (- (car (ly:stencil-extent stl Y)) (car (ly:stencil-extent centered-stl Y))) 0) Y))
     (cons 0 -0.8))))

%=======================================================
#(define-event-class 'jianpu-grace-curve-event 'span-event)

#(define (add-grob-definition grob-name grob-entry)
   (set! all-grob-descriptions
         (cons ((@@ (lily) completize-grob-entry)
                (cons grob-name grob-entry))
               all-grob-descriptions)))

#(define (jianpu-grace-curve-stencil grob)
   (let* ((elts (ly:grob-object grob 'elements))
          (refp-X (ly:grob-common-refpoint-of-array grob elts X))
          (X-ext (ly:relative-group-extent elts refp-X X))
          (refp-Y (ly:grob-common-refpoint-of-array grob elts Y))
          (Y-ext (ly:relative-group-extent elts refp-Y Y))
          (direction (ly:grob-property grob 'direction RIGHT))
          (x-start (* 0.5 (+ (car X-ext) (cdr X-ext))))
          (y-start (+ (car Y-ext) 0.32))
          (x-start2 (if (eq? direction RIGHT)(+ x-start 0.5)(- x-start 0.5)))
          (x-end (if (eq? direction RIGHT)(+ (cdr X-ext) 0.2)(- (car X-ext) 0.2)))
          (y-end (- y-start 0.5))
          (stil (ly:make-stencil `(path 0.1
                                        (moveto ,x-start ,y-start
                                         curveto ,x-start ,y-end ,x-start ,y-end ,x-start2 ,y-end
                                         lineto ,x-end ,y-end))
                                  X-ext
                                  Y-ext))
          (offset (ly:grob-relative-coordinate grob refp-X X)))
     (ly:stencil-translate-axis stil (- offset) X)))

#(add-grob-definition
  'JianpuGraceCurve
  `(
     (stencil . ,jianpu-grace-curve-stencil)
     (meta . ((class . Spanner)
              (interfaces . ())))))

#(define jianpu-grace-curve-types
   '(
      (JianpuGraceCurveEvent
       . ((description . "Used to signal where curve encompassing music start and stop.")
          (types . (general-music jianpu-grace-curve-event span-event event))
          ))
      ))

#(set!
  jianpu-grace-curve-types
  (map (lambda (x)
         (set-object-property! (car x)
           'music-description
           (cdr (assq 'description (cdr x))))
         (let ((lst (cdr x)))
           (set! lst (assoc-set! lst 'name (car x)))
           (set! lst (assq-remove! lst 'description))
           (hashq-set! music-name-to-property-table (car x) lst)
           (cons (car x) lst)))
    jianpu-grace-curve-types))

#(set! music-descriptions
       (append jianpu-grace-curve-types music-descriptions))

#(set! music-descriptions
       (sort music-descriptions alist<?))


#(define (add-bound-item spanner item)
   (if (null? (ly:spanner-bound spanner LEFT))
       (ly:spanner-set-bound! spanner LEFT item)
       (ly:spanner-set-bound! spanner RIGHT item)))

jianpuGraceCurveEngraver =
#(lambda (context)
   (let ((span '())
         (finished '())
         (current-event '())
         (event-start '())
         (event-stop '()))
     `(
       (listeners
        (jianpu-grace-curve-event .
          ,(lambda (engraver event)
             (if (= START (ly:event-property event 'span-direction))
                 (set! event-start event)
                 (set! event-stop event)))))

       (acknowledgers
        (note-column-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)
                  (add-bound-item span grob)))
             (if (ly:spanner? finished)
                 (begin
                  (ly:pointer-group-interface::add-grob finished 'elements grob)
                  (add-bound-item finished grob)))))
        (inline-accidental-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)))
             (if (ly:spanner? finished)
                 (ly:pointer-group-interface::add-grob finished 'elements grob))))
        (script-interface .
          ,(lambda (engraver grob source-engraver)
             (let ((is-dyn (or (grob::has-interface grob 'dynamic-interface)
                       (eq? (ly:grob-property grob 'meta) 'DynamicText))))
               (if (and (ly:spanner? span) (not is-dyn))
                (ly:pointer-group-interface::add-grob span 'elements grob))
               (if (and (ly:spanner? finished) (not is-dyn))
                (ly:pointer-group-interface::add-grob finished 'elements grob))))))
       (process-music .
         ,(lambda (trans)
            (if (ly:stream-event? event-stop)
                (if (null? span)
                    (ly:warning "No start to this curve.")
                    (begin
                     (set! finished span)
                     (ly:engraver-announce-end-grob trans finished event-start)
                     (set! span '())
                     (set! event-stop '()))))
            (if (ly:stream-event? event-start)
                (begin
                 (set! span (ly:engraver-make-grob trans 'JianpuGraceCurve event-start))
                 (set! event-start '())))))
       
       (stop-translation-timestep .
         ,(lambda (trans)
            (if (and (ly:spanner? span)
                     (null? (ly:spanner-bound span LEFT)))
                (ly:spanner-set-bound! span LEFT
                  (ly:context-property context 'currentMusicalColumn)))
            (if (ly:spanner? finished)
                (begin
                 (if (null? (ly:spanner-bound finished RIGHT))
                     (ly:spanner-set-bound! finished RIGHT
                       (ly:context-property context 'currentMusicalColumn)))
                 (set! finished '())
                 (set! event-start '())
                 (set! event-stop '())))))
       
       (finalize
        (lambda (trans)
          (if (ly:spanner? finished)
              (begin
               (if (null? (ly:spanner-bound finished RIGHT))
                   (set! (ly:spanner-bound finished RIGHT)
                         (ly:context-property context 'currentMusicalColumn)))
               (set! finished '())))))
       )))

jianpuGraceCurveStart =
#(make-span-event 'JianpuGraceCurveEvent START)

jianpuGraceCurveEnd =
#(make-span-event 'JianpuGraceCurveEvent STOP)
%===========================================================

%{ The jianpu-ly input was:
4/4
6 7 0 0 | 2 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
0 0 0 0 | 5 0 0 0 | 1 0 0 0 | 0 0 0 0 |
7 - - 1' | - 0 0 0 | 0 0 0 0 |
- - - q2' q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
2 0 0 0 | 0 0 0 0 | 0 0 0 0 |
3 5 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
2 - - 1' | - 0 0 0 | 0 0 0 0 |
- - q2' 0 q0 | - 0 0 0 | 0 0 0 0 |
6. 7 0 q0 | 0 0 0 0 |
1 0 0 0 | 0 0 0 0 |
0 0 0 0 | 3 0 0 0 | 0 0 0 0 |
5 0 0 0 | 0 0 0 0 |
%END
%}


\score {
<< \override Score.BarNumber.break-visibility = #center-visible
\override Score.BarNumber.Y-offset = -1
\set Score.barNumberVisibility = #(every-nth-bar-number-visible 5)

%% === BEGIN JIANPU STAFF ===
    \new RhythmicStaff \with {
    \consists "Accidental_engraver" 
    \consists \jianpuGraceCurveEngraver
    \omit Staff.DotColumn \omit Voice.Dots \override Glissando.before-line-breaking = #jianpu-glissando
    % Get rid of the stave but not the barlines:
    \override StaffSymbol.line-count = #0 % tested in 2.15.40, 2.16.2, 2.18.0, 2.18.2, 2.20.0 and 2.22.2
    \override BarLine.bar-extent = #'(-2 . 2) % LilyPond 2.18: please make barlines as high as the time signature even though we're on a RhythmicStaff (2.16 and 2.15 don't need this although its presence doesn't hurt; Issue 3685 seems to indicate they'll fix it post-2.18)
    $(add-grace-property 'Voice 'Stem 'direction DOWN)
    $(add-grace-property 'Voice 'Slur 'direction UP)
    $(add-grace-property 'Voice 'Stem 'length-fraction 0.5)
    $(add-grace-property 'Voice 'Beam 'beam-thickness 0.1)
    $(add-grace-property 'Voice 'Beam 'length-fraction 0.3)
    $(add-grace-property 'Voice 'Beam 'after-line-breaking flip-beams)
    $(add-grace-property 'Voice 'Beam 'Y-offset 2.5)
    $(add-grace-property 'Voice 'NoteHead 'Y-offset 2.5)
    }
    { \new Voice="W" {
    \override Beam.transparent = ##f
    \override Stem.direction = #DOWN
    \override Tie.staff-position = #2.5
    \tupletUp
    \tieUp
    \override Stem.length-fraction = #0
    \override Beam.beam-thickness = #0.1
    \override Beam.length-fraction = #0.5
    \override Beam.after-line-breaking = #flip-beams
    \override Voice.Rest.style = #'neomensural % this size tends to line up better (we'll override the appearance anyway)
    \override Accidental.font-size = #-4
    \override TupletBracket.bracket-visibility = ##t

    \override Staff.TimeSignature.style = #'numbered
    \override Staff.Stem.transparent = ##t
     \time 4/4  \note-mod "6" a'4  \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 11: %}
 \note-mod "7" b'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" b'4
 ~  \note-mod "–" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "–" r4
 \note-mod "–" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 15: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 16: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 17: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 19: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 20: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 21: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 22: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 23: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 24: %}
 \note-mod "3" e'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 25: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 26: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 27: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 28: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 29: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 30: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 31: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 32: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 33: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 34: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 35: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 36: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 37: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 38: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 39: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 40: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 41: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 42: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 43: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 44: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 45: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 46: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 47: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 48: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 49: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 50: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 51: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 52: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 53: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 54: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 55: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 56: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 57: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 58: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 59: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 60: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 61: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 62: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 63: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 64: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 65: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 66: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 67: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 68: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 69: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 70: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 71: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 72: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 73: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 74: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 75: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 76: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 77: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 78: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 79: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 80: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 81: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 82: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 83: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 84: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 85: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 86: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 87: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 88: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 89: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 90: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 91: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 92: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 93: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 94: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 95: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 96: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 97: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 98: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 99: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 100: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 101: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 102: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 103: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 104: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 105: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 106: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 107: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 108: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 109: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 111: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 112: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 113: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 114: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 115: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 116: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 117: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 118: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 119: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 120: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 121: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 122: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 123: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 124: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 125: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 126: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 127: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 128: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 129: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 130: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 131: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 132: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 133: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 134: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 135: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 136: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 137: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 138: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 139: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 140: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 141: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 142: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 143: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 144: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 145: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 146: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 147: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 148: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 149: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 150: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 151: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 152: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 153: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 154: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 155: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 156: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 157: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 158: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 159: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 160: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 161: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 162: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 163: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 164: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 165: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 166: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 167: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 168: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 169: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 170: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 171: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 172: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 173: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 174: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 175: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 176: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 177: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 178: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 179: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 180: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 181: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 182: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 183: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 184: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 185: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 186: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 187: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 188: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 189: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 190: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 191: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 192: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 193: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 194: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 195: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 196: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 197: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 198: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 199: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 200: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 201: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 202: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 203: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 204: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 205: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 206: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 207: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 208: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 209: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 210: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 211: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 212: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 213: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 214: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 215: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 216: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 217: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 218: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 219: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 220: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 221: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 222: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 223: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 224: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 225: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 226: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 227: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 228: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 229: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 230: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 231: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 232: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 233: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 234: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 235: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 236: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 237: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 238: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 239: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 240: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 241: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 242: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 243: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 244: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 245: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 246: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 247: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 248: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 249: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 250: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 251: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 252: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 253: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 254: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 255: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 256: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 257: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 258: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 259: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 260: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 261: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 262: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 263: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 264: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 265: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 266: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 267: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 268: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 269: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 270: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 271: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 272: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 273: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 274: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 275: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 276: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 277: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 278: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 279: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 280: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 281: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 282: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 283: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 284: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 285: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 286: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 287: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 288: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 289: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 290: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 291: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 292: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 293: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 294: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 295: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 296: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 297: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 298: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 299: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 300: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 301: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 302: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 303: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 304: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 305: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 306: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 307: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 308: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 309: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 310: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 311: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 312: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 313: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 314: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 315: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 316: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 317: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 318: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 319: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 320: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 321: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 322: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 323: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 324: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 325: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 326: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 327: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 328: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 329: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 330: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 331: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 332: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 333: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 334: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 335: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 336: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 337: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 338: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 339: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 340: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 341: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 342: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 343: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 344: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 345: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 346: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 347: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 348: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 349: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 350: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 351: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 352: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 353: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 354: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 355: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 356: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 357: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 358: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 359: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 360: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 361: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 362: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 363: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 364: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 365: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 366: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 367: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 368: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 369: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 370: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 371: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 372: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 373: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 374: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 375: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 376: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 377: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 378: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 379: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 380: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 381: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 382: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 383: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 384: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 385: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 386: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 387: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 388: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 389: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 390: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 391: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 392: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 393: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 394: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 395: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 396: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 397: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 398: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 399: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 400: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 401: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 402: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 403: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 404: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 405: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 406: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 407: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 408: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 409: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 410: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 411: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 412: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 413: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 414: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 415: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 416: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 417: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 418: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 419: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 420: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 421: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 422: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 423: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 424: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 425: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 426: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 427: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 428: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 429: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 430: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 431: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 432: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 433: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 434: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 435: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 436: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 437: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 438: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 439: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 440: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 441: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 442: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 443: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 444: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 445: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 446: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 447: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 448: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 449: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 450: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 451: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 452: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 453: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 454: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 455: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 456: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 457: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 458: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 459: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 460: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 461: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 462: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 463: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 464: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 465: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 466: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 467: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 468: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 469: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 470: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 471: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 472: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 473: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 474: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 475: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 476: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 477: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 478: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 479: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 480: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 481: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 482: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 483: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 484: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 485: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 486: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 487: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 488: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 489: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 490: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 491: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 492: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 493: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 494: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 495: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 496: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 497: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 498: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 499: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 500: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 501: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 502: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 503: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 504: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 505: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 506: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 507: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 508: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 509: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 510: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 511: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 512: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 513: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 514: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 515: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 516: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 517: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 518: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 519: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 520: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 521: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 522: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 523: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 524: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 525: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 526: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 527: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 528: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 529: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 530: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 531: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 532: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 533: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 534: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 535: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 536: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 537: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 538: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 539: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 540: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 541: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 542: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 543: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 544: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 545: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 546: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 547: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 548: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 549: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 550: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 551: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 552: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 553: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 554: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 555: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 556: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 557: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 558: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 559: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 560: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 561: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 562: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 563: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 564: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 565: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 566: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 567: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 568: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 569: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 570: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 571: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 572: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 573: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 574: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 575: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 576: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 577: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 578: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 579: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 580: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 581: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 582: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 583: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 584: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 585: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 586: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 587: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 588: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 589: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 590: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 591: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 592: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 593: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 594: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 595: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 596: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 597: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 598: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 599: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 600: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 601: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 602: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 603: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 604: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 605: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 606: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 607: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 608: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 609: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 610: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 611: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 612: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 613: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 614: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 615: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 616: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 617: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 618: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 619: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 620: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 621: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 622: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 623: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 624: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 625: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 626: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 627: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 628: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 629: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 630: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 631: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 632: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 633: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 634: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 635: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 636: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 637: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 638: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 639: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 640: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 641: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 642: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 643: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 644: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 645: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 646: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 647: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 648: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 649: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 650: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 651: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 652: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 653: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 654: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 655: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 656: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 657: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 658: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 659: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 660: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 661: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 662: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 663: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 664: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 665: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 666: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 667: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 668: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 669: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 670: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 671: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 672: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 673: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 674: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 675: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 676: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 677: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 678: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 679: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 680: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 681: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 682: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 683: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 684: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 685: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 686: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 687: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 688: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 689: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 690: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 691: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 692: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 693: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 694: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 695: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 696: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 697: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 698: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 699: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 700: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 701: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 702: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 703: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 704: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 705: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 706: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 707: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 708: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 709: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 710: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 711: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 712: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 713: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 714: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 715: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 716: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 717: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 718: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 719: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 720: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 721: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 722: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 723: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 724: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 725: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 726: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 727: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 728: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 729: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 730: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 731: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 732: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 733: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 734: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 735: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 736: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 737: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 738: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 739: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 740: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 741: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 742: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 743: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 744: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 745: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 746: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 747: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 748: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 749: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 750: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 751: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 752: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 753: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 754: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 755: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 756: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 757: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 758: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 759: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 760: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 761: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 762: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 763: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 764: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 765: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 766: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 767: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 768: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 769: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 770: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 771: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 772: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 773: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 774: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 775: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 776: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 777: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 778: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 779: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 780: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 781: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 782: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 783: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 784: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 785: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 786: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 787: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 788: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 789: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 790: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 791: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 792: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 793: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 794: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 795: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 796: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 797: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 798: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 799: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 800: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 801: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 802: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 803: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 804: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 805: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 806: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 807: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 808: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 809: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 810: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 811: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 812: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 813: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 814: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 815: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 816: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 817: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 818: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 819: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 820: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 821: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 822: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 823: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 824: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 825: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 826: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 827: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 828: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 829: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 830: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 831: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 832: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 833: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 834: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 835: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 836: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 837: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 838: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 839: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 840: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 841: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 842: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 843: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 844: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 845: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 846: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 847: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 848: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 849: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 850: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 851: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 852: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 853: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 854: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 855: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 856: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 857: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 858: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 859: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 860: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 861: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 862: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 863: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 864: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 865: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 866: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 867: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 868: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 869: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 870: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 871: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 872: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 873: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 874: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 875: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 876: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 877: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 878: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 879: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 880: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 881: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 882: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 883: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 884: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 885: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 886: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 887: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 888: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 889: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 890: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 891: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 892: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 893: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 894: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 895: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 896: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 897: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 898: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 899: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 900: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 901: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 902: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 903: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 904: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 905: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 906: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 907: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 908: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 909: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 910: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 911: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 912: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 913: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 914: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 915: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 916: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 917: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 918: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 919: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 920: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 921: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 922: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 923: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 924: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 925: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 926: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 927: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 928: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 929: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 930: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 931: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 932: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 933: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 934: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 935: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 936: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 937: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 938: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 939: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 940: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 941: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 942: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 943: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 944: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 945: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 946: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 947: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 948: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 949: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 950: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 951: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 952: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 953: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 954: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 955: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 956: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 957: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 958: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 959: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 960: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 961: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 962: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 963: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 964: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 965: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 966: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 967: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 968: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 969: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 970: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 971: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 972: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 973: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 974: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 975: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 976: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 977: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 978: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 979: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 980: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 981: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 982: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 983: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 984: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 985: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 986: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 987: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 988: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 989: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 990: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 991: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 992: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 993: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 994: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 995: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 996: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 997: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 998: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 999: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1000: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1001: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1002: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1003: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1004: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1005: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1006: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1007: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1008: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1009: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1010: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1011: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1012: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1013: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1014: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1015: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1016: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1017: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1018: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1019: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1020: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1021: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1022: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1023: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1024: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1025: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1026: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1027: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1028: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1029: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1030: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1031: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1032: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1033: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1034: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1035: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1036: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1037: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1038: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1039: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1040: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1041: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1042: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1043: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1044: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1045: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1046: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1047: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1048: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1049: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1050: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1051: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1052: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1053: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1054: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1055: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1056: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1057: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1058: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1059: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1060: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1061: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1062: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1063: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1064: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1065: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1066: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1067: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1068: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1069: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1070: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1071: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1072: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1073: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1074: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1075: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1076: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1077: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1078: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1079: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1080: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1081: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1082: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1083: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1084: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1085: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1086: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1087: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1088: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1089: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1090: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1091: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1092: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1093: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1094: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1095: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1096: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1097: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1098: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1099: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1100: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1101: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1102: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1103: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1104: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1105: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1106: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1107: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1108: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1109: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1110: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1111: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1112: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1113: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1114: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1115: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1116: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1117: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1118: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1119: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1120: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1121: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1122: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1123: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1124: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1125: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1126: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1127: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1128: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1129: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1130: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1131: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1132: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1133: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1134: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1135: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1136: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1137: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1138: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1139: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1140: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1141: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1142: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1143: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1144: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1145: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1146: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1147: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1148: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1149: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1150: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1151: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1152: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1153: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1154: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1155: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1156: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1157: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1158: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1159: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1160: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1161: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1162: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1163: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1164: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1165: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 1166: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
\=JianpuTie(  ~ | | %{ bar 1167: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1168: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1169: %}
 \note-mod "–" r4
 \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1170: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1171: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1172: %}
 \note-mod "6" a'4.
 \note-mod "7" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 1173: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1174: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1175: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1176: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1177: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1178: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1179: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 1180: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\layout{
  \context {
    \Global
    \grobdescriptions #all-grob-descriptions
  }
} }
\score {
\unfoldRepeats
<< 

% === BEGIN MIDI STAFF ===
    \new Staff { \new Voice="X" { \time 4/4 a'4 b'4 r2 | | %{ bar 2: %} d'4 r2. | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} e'4 r2. | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} g'4 r2. | | %{ bar 9: %} c'4 r2. | | %{ bar 10: %} R1 | | %{ bar 11: %} b'2. c''4  ~ | | %{ bar 12: %} c''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} r2. d''8 r8 | | %{ bar 15: %} R1 | | %{ bar 16: %} R1 | | %{ bar 17: %} a'4. b'4 r4 r8 | | %{ bar 18: %} R1 | | %{ bar 19: %} c'4 r2. | | %{ bar 20: %} R1 | | %{ bar 21: %} d'4 r2. | | %{ bar 22: %} R1 | | %{ bar 23: %} R1 | | %{ bar 24: %} e'4 g'4 r2 | | %{ bar 25: %} R1 | | %{ bar 26: %} d'2. c''4  ~ | | %{ bar 27: %} c''4 r2. | | %{ bar 28: %} R1 | | %{ bar 29: %} r2 d''8 r4 r8 | | %{ bar 30: %} R1 | | %{ bar 31: %} R1 | | %{ bar 32: %} a'4. b'4 r4 r8 | | %{ bar 33: %} R1 | | %{ bar 34: %} c'4 r2. | | %{ bar 35: %} R1 | | %{ bar 36: %} R1 | | %{ bar 37: %} e'4 r2. | | %{ bar 38: %} R1 | | %{ bar 39: %} g'4 r2. | | %{ bar 40: %} R1 | | %{ bar 41: %} d'2. c''4  ~ | | %{ bar 42: %} c''4 r2. | | %{ bar 43: %} R1 | | %{ bar 44: %} r2 d''8 r4 r8 | | %{ bar 45: %} R1 | | %{ bar 46: %} R1 | | %{ bar 47: %} a'4. b'4 r4 r8 | | %{ bar 48: %} R1 | | %{ bar 49: %} c'4 r2. | | %{ bar 50: %} R1 | | %{ bar 51: %} R1 | | %{ bar 52: %} e'4 r2. | | %{ bar 53: %} R1 | | %{ bar 54: %} g'4 r2. | | %{ bar 55: %} R1 | | %{ bar 56: %} d'2. c''4  ~ | | %{ bar 57: %} c''4 r2. | | %{ bar 58: %} R1 | | %{ bar 59: %} r2 d''8 r4 r8 | | %{ bar 60: %} R1 | | %{ bar 61: %} R1 | | %{ bar 62: %} a'4. b'4 r4 r8 | | %{ bar 63: %} R1 | | %{ bar 64: %} c'4 r2. | | %{ bar 65: %} R1 | | %{ bar 66: %} R1 | | %{ bar 67: %} e'4 r2. | | %{ bar 68: %} R1 | | %{ bar 69: %} g'4 r2. | | %{ bar 70: %} R1 | | %{ bar 71: %} d'2. c''4  ~ | | %{ bar 72: %} c''4 r2. | | %{ bar 73: %} R1 | | %{ bar 74: %} r2 d''8 r4 r8 | | %{ bar 75: %} R1 | | %{ bar 76: %} R1 | | %{ bar 77: %} a'4. b'4 r4 r8 | | %{ bar 78: %} R1 | | %{ bar 79: %} c'4 r2. | | %{ bar 80: %} R1 | | %{ bar 81: %} R1 | | %{ bar 82: %} e'4 r2. | | %{ bar 83: %} R1 | | %{ bar 84: %} g'4 r2. | | %{ bar 85: %} R1 | | %{ bar 86: %} d'2. c''4  ~ | | %{ bar 87: %} c''4 r2. | | %{ bar 88: %} R1 | | %{ bar 89: %} r2 d''8 r4 r8 | | %{ bar 90: %} R1 | | %{ bar 91: %} R1 | | %{ bar 92: %} a'4. b'4 r4 r8 | | %{ bar 93: %} R1 | | %{ bar 94: %} c'4 r2. | | %{ bar 95: %} R1 | | %{ bar 96: %} R1 | | %{ bar 97: %} e'4 r2. | | %{ bar 98: %} R1 | | %{ bar 99: %} g'4 r2. | | %{ bar 100: %} R1 | | %{ bar 101: %} d'2. c''4  ~ | | %{ bar 102: %} c''4 r2. | | %{ bar 103: %} R1 | | %{ bar 104: %} r2 d''8 r4 r8 | | %{ bar 105: %} R1 | | %{ bar 106: %} R1 | | %{ bar 107: %} a'4. b'4 r4 r8 | | %{ bar 108: %} R1 | | %{ bar 109: %} c'4 r2. | | %{ bar 110: %} R1 | | %{ bar 111: %} R1 | | %{ bar 112: %} e'4 r2. | | %{ bar 113: %} R1 | | %{ bar 114: %} g'4 r2. | | %{ bar 115: %} R1 | | %{ bar 116: %} d'2. c''4  ~ | | %{ bar 117: %} c''4 r2. | | %{ bar 118: %} R1 | | %{ bar 119: %} r2 d''8 r4 r8 | | %{ bar 120: %} R1 | | %{ bar 121: %} R1 | | %{ bar 122: %} a'4. b'4 r4 r8 | | %{ bar 123: %} R1 | | %{ bar 124: %} c'4 r2. | | %{ bar 125: %} R1 | | %{ bar 126: %} R1 | | %{ bar 127: %} e'4 r2. | | %{ bar 128: %} R1 | | %{ bar 129: %} g'4 r2. | | %{ bar 130: %} R1 | | %{ bar 131: %} d'2. c''4  ~ | | %{ bar 132: %} c''4 r2. | | %{ bar 133: %} R1 | | %{ bar 134: %} r2 d''8 r4 r8 | | %{ bar 135: %} R1 | | %{ bar 136: %} R1 | | %{ bar 137: %} a'4. b'4 r4 r8 | | %{ bar 138: %} R1 | | %{ bar 139: %} c'4 r2. | | %{ bar 140: %} R1 | | %{ bar 141: %} R1 | | %{ bar 142: %} e'4 r2. | | %{ bar 143: %} R1 | | %{ bar 144: %} g'4 r2. | | %{ bar 145: %} R1 | | %{ bar 146: %} d'2. c''4  ~ | | %{ bar 147: %} c''4 r2. | | %{ bar 148: %} R1 | | %{ bar 149: %} r2 d''8 r4 r8 | | %{ bar 150: %} R1 | | %{ bar 151: %} R1 | | %{ bar 152: %} a'4. b'4 r4 r8 | | %{ bar 153: %} R1 | | %{ bar 154: %} c'4 r2. | | %{ bar 155: %} R1 | | %{ bar 156: %} R1 | | %{ bar 157: %} e'4 r2. | | %{ bar 158: %} R1 | | %{ bar 159: %} g'4 r2. | | %{ bar 160: %} R1 | | %{ bar 161: %} d'2. c''4  ~ | | %{ bar 162: %} c''4 r2. | | %{ bar 163: %} R1 | | %{ bar 164: %} r2 d''8 r4 r8 | | %{ bar 165: %} R1 | | %{ bar 166: %} R1 | | %{ bar 167: %} a'4. b'4 r4 r8 | | %{ bar 168: %} R1 | | %{ bar 169: %} c'4 r2. | | %{ bar 170: %} R1 | | %{ bar 171: %} R1 | | %{ bar 172: %} e'4 r2. | | %{ bar 173: %} R1 | | %{ bar 174: %} g'4 r2. | | %{ bar 175: %} R1 | | %{ bar 176: %} d'2. c''4  ~ | | %{ bar 177: %} c''4 r2. | | %{ bar 178: %} R1 | | %{ bar 179: %} r2 d''8 r4 r8 | | %{ bar 180: %} R1 | | %{ bar 181: %} R1 | | %{ bar 182: %} a'4. b'4 r4 r8 | | %{ bar 183: %} R1 | | %{ bar 184: %} c'4 r2. | | %{ bar 185: %} R1 | | %{ bar 186: %} R1 | | %{ bar 187: %} e'4 r2. | | %{ bar 188: %} R1 | | %{ bar 189: %} g'4 r2. | | %{ bar 190: %} R1 | | %{ bar 191: %} d'2. c''4  ~ | | %{ bar 192: %} c''4 r2. | | %{ bar 193: %} R1 | | %{ bar 194: %} r2 d''8 r4 r8 | | %{ bar 195: %} R1 | | %{ bar 196: %} R1 | | %{ bar 197: %} a'4. b'4 r4 r8 | | %{ bar 198: %} R1 | | %{ bar 199: %} c'4 r2. | | %{ bar 200: %} R1 | | %{ bar 201: %} R1 | | %{ bar 202: %} e'4 r2. | | %{ bar 203: %} R1 | | %{ bar 204: %} g'4 r2. | | %{ bar 205: %} R1 | | %{ bar 206: %} d'2. c''4  ~ | | %{ bar 207: %} c''4 r2. | | %{ bar 208: %} R1 | | %{ bar 209: %} r2 d''8 r4 r8 | | %{ bar 210: %} R1 | | %{ bar 211: %} R1 | | %{ bar 212: %} a'4. b'4 r4 r8 | | %{ bar 213: %} R1 | | %{ bar 214: %} c'4 r2. | | %{ bar 215: %} R1 | | %{ bar 216: %} R1 | | %{ bar 217: %} e'4 r2. | | %{ bar 218: %} R1 | | %{ bar 219: %} g'4 r2. | | %{ bar 220: %} R1 | | %{ bar 221: %} d'2. c''4  ~ | | %{ bar 222: %} c''4 r2. | | %{ bar 223: %} R1 | | %{ bar 224: %} r2 d''8 r4 r8 | | %{ bar 225: %} R1 | | %{ bar 226: %} R1 | | %{ bar 227: %} a'4. b'4 r4 r8 | | %{ bar 228: %} R1 | | %{ bar 229: %} c'4 r2. | | %{ bar 230: %} R1 | | %{ bar 231: %} R1 | | %{ bar 232: %} e'4 r2. | | %{ bar 233: %} R1 | | %{ bar 234: %} g'4 r2. | | %{ bar 235: %} R1 | | %{ bar 236: %} d'2. c''4  ~ | | %{ bar 237: %} c''4 r2. | | %{ bar 238: %} R1 | | %{ bar 239: %} r2 d''8 r4 r8 | | %{ bar 240: %} R1 | | %{ bar 241: %} R1 | | %{ bar 242: %} a'4. b'4 r4 r8 | | %{ bar 243: %} R1 | | %{ bar 244: %} c'4 r2. | | %{ bar 245: %} R1 | | %{ bar 246: %} R1 | | %{ bar 247: %} e'4 r2. | | %{ bar 248: %} R1 | | %{ bar 249: %} g'4 r2. | | %{ bar 250: %} R1 | | %{ bar 251: %} d'2. c''4  ~ | | %{ bar 252: %} c''4 r2. | | %{ bar 253: %} R1 | | %{ bar 254: %} r2 d''8 r4 r8 | | %{ bar 255: %} R1 | | %{ bar 256: %} R1 | | %{ bar 257: %} a'4. b'4 r4 r8 | | %{ bar 258: %} R1 | | %{ bar 259: %} c'4 r2. | | %{ bar 260: %} R1 | | %{ bar 261: %} R1 | | %{ bar 262: %} e'4 r2. | | %{ bar 263: %} R1 | | %{ bar 264: %} g'4 r2. | | %{ bar 265: %} R1 | | %{ bar 266: %} d'2. c''4  ~ | | %{ bar 267: %} c''4 r2. | | %{ bar 268: %} R1 | | %{ bar 269: %} r2 d''8 r4 r8 | | %{ bar 270: %} R1 | | %{ bar 271: %} R1 | | %{ bar 272: %} a'4. b'4 r4 r8 | | %{ bar 273: %} R1 | | %{ bar 274: %} c'4 r2. | | %{ bar 275: %} R1 | | %{ bar 276: %} R1 | | %{ bar 277: %} e'4 r2. | | %{ bar 278: %} R1 | | %{ bar 279: %} g'4 r2. | | %{ bar 280: %} R1 | | %{ bar 281: %} d'2. c''4  ~ | | %{ bar 282: %} c''4 r2. | | %{ bar 283: %} R1 | | %{ bar 284: %} r2 d''8 r4 r8 | | %{ bar 285: %} R1 | | %{ bar 286: %} R1 | | %{ bar 287: %} a'4. b'4 r4 r8 | | %{ bar 288: %} R1 | | %{ bar 289: %} c'4 r2. | | %{ bar 290: %} R1 | | %{ bar 291: %} R1 | | %{ bar 292: %} e'4 r2. | | %{ bar 293: %} R1 | | %{ bar 294: %} g'4 r2. | | %{ bar 295: %} R1 | | %{ bar 296: %} d'2. c''4  ~ | | %{ bar 297: %} c''4 r2. | | %{ bar 298: %} R1 | | %{ bar 299: %} r2 d''8 r4 r8 | | %{ bar 300: %} R1 | | %{ bar 301: %} R1 | | %{ bar 302: %} a'4. b'4 r4 r8 | | %{ bar 303: %} R1 | | %{ bar 304: %} c'4 r2. | | %{ bar 305: %} R1 | | %{ bar 306: %} R1 | | %{ bar 307: %} e'4 r2. | | %{ bar 308: %} R1 | | %{ bar 309: %} g'4 r2. | | %{ bar 310: %} R1 | | %{ bar 311: %} d'2. c''4  ~ | | %{ bar 312: %} c''4 r2. | | %{ bar 313: %} R1 | | %{ bar 314: %} r2 d''8 r4 r8 | | %{ bar 315: %} R1 | | %{ bar 316: %} R1 | | %{ bar 317: %} a'4. b'4 r4 r8 | | %{ bar 318: %} R1 | | %{ bar 319: %} c'4 r2. | | %{ bar 320: %} R1 | | %{ bar 321: %} R1 | | %{ bar 322: %} e'4 r2. | | %{ bar 323: %} R1 | | %{ bar 324: %} g'4 r2. | | %{ bar 325: %} R1 | | %{ bar 326: %} d'2. c''4  ~ | | %{ bar 327: %} c''4 r2. | | %{ bar 328: %} R1 | | %{ bar 329: %} r2 d''8 r4 r8 | | %{ bar 330: %} R1 | | %{ bar 331: %} R1 | | %{ bar 332: %} a'4. b'4 r4 r8 | | %{ bar 333: %} R1 | | %{ bar 334: %} c'4 r2. | | %{ bar 335: %} R1 | | %{ bar 336: %} R1 | | %{ bar 337: %} e'4 r2. | | %{ bar 338: %} R1 | | %{ bar 339: %} g'4 r2. | | %{ bar 340: %} R1 | | %{ bar 341: %} d'2. c''4  ~ | | %{ bar 342: %} c''4 r2. | | %{ bar 343: %} R1 | | %{ bar 344: %} r2 d''8 r4 r8 | | %{ bar 345: %} R1 | | %{ bar 346: %} R1 | | %{ bar 347: %} a'4. b'4 r4 r8 | | %{ bar 348: %} R1 | | %{ bar 349: %} c'4 r2. | | %{ bar 350: %} R1 | | %{ bar 351: %} R1 | | %{ bar 352: %} e'4 r2. | | %{ bar 353: %} R1 | | %{ bar 354: %} g'4 r2. | | %{ bar 355: %} R1 | | %{ bar 356: %} d'2. c''4  ~ | | %{ bar 357: %} c''4 r2. | | %{ bar 358: %} R1 | | %{ bar 359: %} r2 d''8 r4 r8 | | %{ bar 360: %} R1 | | %{ bar 361: %} R1 | | %{ bar 362: %} a'4. b'4 r4 r8 | | %{ bar 363: %} R1 | | %{ bar 364: %} c'4 r2. | | %{ bar 365: %} R1 | | %{ bar 366: %} R1 | | %{ bar 367: %} e'4 r2. | | %{ bar 368: %} R1 | | %{ bar 369: %} g'4 r2. | | %{ bar 370: %} R1 | | %{ bar 371: %} d'2. c''4  ~ | | %{ bar 372: %} c''4 r2. | | %{ bar 373: %} R1 | | %{ bar 374: %} r2 d''8 r4 r8 | | %{ bar 375: %} R1 | | %{ bar 376: %} R1 | | %{ bar 377: %} a'4. b'4 r4 r8 | | %{ bar 378: %} R1 | | %{ bar 379: %} c'4 r2. | | %{ bar 380: %} R1 | | %{ bar 381: %} R1 | | %{ bar 382: %} e'4 r2. | | %{ bar 383: %} R1 | | %{ bar 384: %} g'4 r2. | | %{ bar 385: %} R1 | | %{ bar 386: %} d'2. c''4  ~ | | %{ bar 387: %} c''4 r2. | | %{ bar 388: %} R1 | | %{ bar 389: %} r2 d''8 r4 r8 | | %{ bar 390: %} R1 | | %{ bar 391: %} R1 | | %{ bar 392: %} a'4. b'4 r4 r8 | | %{ bar 393: %} R1 | | %{ bar 394: %} c'4 r2. | | %{ bar 395: %} R1 | | %{ bar 396: %} R1 | | %{ bar 397: %} e'4 r2. | | %{ bar 398: %} R1 | | %{ bar 399: %} g'4 r2. | | %{ bar 400: %} R1 | | %{ bar 401: %} d'2. c''4  ~ | | %{ bar 402: %} c''4 r2. | | %{ bar 403: %} R1 | | %{ bar 404: %} r2 d''8 r4 r8 | | %{ bar 405: %} R1 | | %{ bar 406: %} R1 | | %{ bar 407: %} a'4. b'4 r4 r8 | | %{ bar 408: %} R1 | | %{ bar 409: %} c'4 r2. | | %{ bar 410: %} R1 | | %{ bar 411: %} R1 | | %{ bar 412: %} e'4 r2. | | %{ bar 413: %} R1 | | %{ bar 414: %} g'4 r2. | | %{ bar 415: %} R1 | | %{ bar 416: %} d'2. c''4  ~ | | %{ bar 417: %} c''4 r2. | | %{ bar 418: %} R1 | | %{ bar 419: %} r2 d''8 r4 r8 | | %{ bar 420: %} R1 | | %{ bar 421: %} R1 | | %{ bar 422: %} a'4. b'4 r4 r8 | | %{ bar 423: %} R1 | | %{ bar 424: %} c'4 r2. | | %{ bar 425: %} R1 | | %{ bar 426: %} R1 | | %{ bar 427: %} e'4 r2. | | %{ bar 428: %} R1 | | %{ bar 429: %} g'4 r2. | | %{ bar 430: %} R1 | | %{ bar 431: %} d'2. c''4  ~ | | %{ bar 432: %} c''4 r2. | | %{ bar 433: %} R1 | | %{ bar 434: %} r2 d''8 r4 r8 | | %{ bar 435: %} R1 | | %{ bar 436: %} R1 | | %{ bar 437: %} a'4. b'4 r4 r8 | | %{ bar 438: %} R1 | | %{ bar 439: %} c'4 r2. | | %{ bar 440: %} R1 | | %{ bar 441: %} R1 | | %{ bar 442: %} e'4 r2. | | %{ bar 443: %} R1 | | %{ bar 444: %} g'4 r2. | | %{ bar 445: %} R1 | | %{ bar 446: %} d'2. c''4  ~ | | %{ bar 447: %} c''4 r2. | | %{ bar 448: %} R1 | | %{ bar 449: %} r2 d''8 r4 r8 | | %{ bar 450: %} R1 | | %{ bar 451: %} R1 | | %{ bar 452: %} a'4. b'4 r4 r8 | | %{ bar 453: %} R1 | | %{ bar 454: %} c'4 r2. | | %{ bar 455: %} R1 | | %{ bar 456: %} R1 | | %{ bar 457: %} e'4 r2. | | %{ bar 458: %} R1 | | %{ bar 459: %} g'4 r2. | | %{ bar 460: %} R1 | | %{ bar 461: %} d'2. c''4  ~ | | %{ bar 462: %} c''4 r2. | | %{ bar 463: %} R1 | | %{ bar 464: %} r2 d''8 r4 r8 | | %{ bar 465: %} R1 | | %{ bar 466: %} R1 | | %{ bar 467: %} a'4. b'4 r4 r8 | | %{ bar 468: %} R1 | | %{ bar 469: %} c'4 r2. | | %{ bar 470: %} R1 | | %{ bar 471: %} R1 | | %{ bar 472: %} e'4 r2. | | %{ bar 473: %} R1 | | %{ bar 474: %} g'4 r2. | | %{ bar 475: %} R1 | | %{ bar 476: %} d'2. c''4  ~ | | %{ bar 477: %} c''4 r2. | | %{ bar 478: %} R1 | | %{ bar 479: %} r2 d''8 r4 r8 | | %{ bar 480: %} R1 | | %{ bar 481: %} R1 | | %{ bar 482: %} a'4. b'4 r4 r8 | | %{ bar 483: %} R1 | | %{ bar 484: %} c'4 r2. | | %{ bar 485: %} R1 | | %{ bar 486: %} R1 | | %{ bar 487: %} e'4 r2. | | %{ bar 488: %} R1 | | %{ bar 489: %} g'4 r2. | | %{ bar 490: %} R1 | | %{ bar 491: %} d'2. c''4  ~ | | %{ bar 492: %} c''4 r2. | | %{ bar 493: %} R1 | | %{ bar 494: %} r2 d''8 r4 r8 | | %{ bar 495: %} R1 | | %{ bar 496: %} R1 | | %{ bar 497: %} a'4. b'4 r4 r8 | | %{ bar 498: %} R1 | | %{ bar 499: %} c'4 r2. | | %{ bar 500: %} R1 | | %{ bar 501: %} R1 | | %{ bar 502: %} e'4 r2. | | %{ bar 503: %} R1 | | %{ bar 504: %} g'4 r2. | | %{ bar 505: %} R1 | | %{ bar 506: %} d'2. c''4  ~ | | %{ bar 507: %} c''4 r2. | | %{ bar 508: %} R1 | | %{ bar 509: %} r2 d''8 r4 r8 | | %{ bar 510: %} R1 | | %{ bar 511: %} R1 | | %{ bar 512: %} a'4. b'4 r4 r8 | | %{ bar 513: %} R1 | | %{ bar 514: %} c'4 r2. | | %{ bar 515: %} R1 | | %{ bar 516: %} R1 | | %{ bar 517: %} e'4 r2. | | %{ bar 518: %} R1 | | %{ bar 519: %} g'4 r2. | | %{ bar 520: %} R1 | | %{ bar 521: %} d'2. c''4  ~ | | %{ bar 522: %} c''4 r2. | | %{ bar 523: %} R1 | | %{ bar 524: %} r2 d''8 r4 r8 | | %{ bar 525: %} R1 | | %{ bar 526: %} R1 | | %{ bar 527: %} a'4. b'4 r4 r8 | | %{ bar 528: %} R1 | | %{ bar 529: %} c'4 r2. | | %{ bar 530: %} R1 | | %{ bar 531: %} R1 | | %{ bar 532: %} e'4 r2. | | %{ bar 533: %} R1 | | %{ bar 534: %} g'4 r2. | | %{ bar 535: %} R1 | | %{ bar 536: %} d'2. c''4  ~ | | %{ bar 537: %} c''4 r2. | | %{ bar 538: %} R1 | | %{ bar 539: %} r2 d''8 r4 r8 | | %{ bar 540: %} R1 | | %{ bar 541: %} R1 | | %{ bar 542: %} a'4. b'4 r4 r8 | | %{ bar 543: %} R1 | | %{ bar 544: %} c'4 r2. | | %{ bar 545: %} R1 | | %{ bar 546: %} R1 | | %{ bar 547: %} e'4 r2. | | %{ bar 548: %} R1 | | %{ bar 549: %} g'4 r2. | | %{ bar 550: %} R1 | | %{ bar 551: %} d'2. c''4  ~ | | %{ bar 552: %} c''4 r2. | | %{ bar 553: %} R1 | | %{ bar 554: %} r2 d''8 r4 r8 | | %{ bar 555: %} R1 | | %{ bar 556: %} R1 | | %{ bar 557: %} a'4. b'4 r4 r8 | | %{ bar 558: %} R1 | | %{ bar 559: %} c'4 r2. | | %{ bar 560: %} R1 | | %{ bar 561: %} R1 | | %{ bar 562: %} e'4 r2. | | %{ bar 563: %} R1 | | %{ bar 564: %} g'4 r2. | | %{ bar 565: %} R1 | | %{ bar 566: %} d'2. c''4  ~ | | %{ bar 567: %} c''4 r2. | | %{ bar 568: %} R1 | | %{ bar 569: %} r2 d''8 r4 r8 | | %{ bar 570: %} R1 | | %{ bar 571: %} R1 | | %{ bar 572: %} a'4. b'4 r4 r8 | | %{ bar 573: %} R1 | | %{ bar 574: %} c'4 r2. | | %{ bar 575: %} R1 | | %{ bar 576: %} R1 | | %{ bar 577: %} e'4 r2. | | %{ bar 578: %} R1 | | %{ bar 579: %} g'4 r2. | | %{ bar 580: %} R1 | | %{ bar 581: %} d'2. c''4  ~ | | %{ bar 582: %} c''4 r2. | | %{ bar 583: %} R1 | | %{ bar 584: %} r2 d''8 r4 r8 | | %{ bar 585: %} R1 | | %{ bar 586: %} R1 | | %{ bar 587: %} a'4. b'4 r4 r8 | | %{ bar 588: %} R1 | | %{ bar 589: %} c'4 r2. | | %{ bar 590: %} R1 | | %{ bar 591: %} R1 | | %{ bar 592: %} e'4 r2. | | %{ bar 593: %} R1 | | %{ bar 594: %} g'4 r2. | | %{ bar 595: %} R1 | | %{ bar 596: %} d'2. c''4  ~ | | %{ bar 597: %} c''4 r2. | | %{ bar 598: %} R1 | | %{ bar 599: %} r2 d''8 r4 r8 | | %{ bar 600: %} R1 | | %{ bar 601: %} R1 | | %{ bar 602: %} a'4. b'4 r4 r8 | | %{ bar 603: %} R1 | | %{ bar 604: %} c'4 r2. | | %{ bar 605: %} R1 | | %{ bar 606: %} R1 | | %{ bar 607: %} e'4 r2. | | %{ bar 608: %} R1 | | %{ bar 609: %} g'4 r2. | | %{ bar 610: %} R1 | | %{ bar 611: %} d'2. c''4  ~ | | %{ bar 612: %} c''4 r2. | | %{ bar 613: %} R1 | | %{ bar 614: %} r2 d''8 r4 r8 | | %{ bar 615: %} R1 | | %{ bar 616: %} R1 | | %{ bar 617: %} a'4. b'4 r4 r8 | | %{ bar 618: %} R1 | | %{ bar 619: %} c'4 r2. | | %{ bar 620: %} R1 | | %{ bar 621: %} R1 | | %{ bar 622: %} e'4 r2. | | %{ bar 623: %} R1 | | %{ bar 624: %} g'4 r2. | | %{ bar 625: %} R1 | | %{ bar 626: %} d'2. c''4  ~ | | %{ bar 627: %} c''4 r2. | | %{ bar 628: %} R1 | | %{ bar 629: %} r2 d''8 r4 r8 | | %{ bar 630: %} R1 | | %{ bar 631: %} R1 | | %{ bar 632: %} a'4. b'4 r4 r8 | | %{ bar 633: %} R1 | | %{ bar 634: %} c'4 r2. | | %{ bar 635: %} R1 | | %{ bar 636: %} R1 | | %{ bar 637: %} e'4 r2. | | %{ bar 638: %} R1 | | %{ bar 639: %} g'4 r2. | | %{ bar 640: %} R1 | | %{ bar 641: %} d'2. c''4  ~ | | %{ bar 642: %} c''4 r2. | | %{ bar 643: %} R1 | | %{ bar 644: %} r2 d''8 r4 r8 | | %{ bar 645: %} R1 | | %{ bar 646: %} R1 | | %{ bar 647: %} a'4. b'4 r4 r8 | | %{ bar 648: %} R1 | | %{ bar 649: %} c'4 r2. | | %{ bar 650: %} R1 | | %{ bar 651: %} R1 | | %{ bar 652: %} e'4 r2. | | %{ bar 653: %} R1 | | %{ bar 654: %} g'4 r2. | | %{ bar 655: %} R1 | | %{ bar 656: %} d'2. c''4  ~ | | %{ bar 657: %} c''4 r2. | | %{ bar 658: %} R1 | | %{ bar 659: %} r2 d''8 r4 r8 | | %{ bar 660: %} R1 | | %{ bar 661: %} R1 | | %{ bar 662: %} a'4. b'4 r4 r8 | | %{ bar 663: %} R1 | | %{ bar 664: %} c'4 r2. | | %{ bar 665: %} R1 | | %{ bar 666: %} R1 | | %{ bar 667: %} e'4 r2. | | %{ bar 668: %} R1 | | %{ bar 669: %} g'4 r2. | | %{ bar 670: %} R1 | | %{ bar 671: %} d'2. c''4  ~ | | %{ bar 672: %} c''4 r2. | | %{ bar 673: %} R1 | | %{ bar 674: %} r2 d''8 r4 r8 | | %{ bar 675: %} R1 | | %{ bar 676: %} R1 | | %{ bar 677: %} a'4. b'4 r4 r8 | | %{ bar 678: %} R1 | | %{ bar 679: %} c'4 r2. | | %{ bar 680: %} R1 | | %{ bar 681: %} R1 | | %{ bar 682: %} e'4 r2. | | %{ bar 683: %} R1 | | %{ bar 684: %} g'4 r2. | | %{ bar 685: %} R1 | | %{ bar 686: %} d'2. c''4  ~ | | %{ bar 687: %} c''4 r2. | | %{ bar 688: %} R1 | | %{ bar 689: %} r2 d''8 r4 r8 | | %{ bar 690: %} R1 | | %{ bar 691: %} R1 | | %{ bar 692: %} a'4. b'4 r4 r8 | | %{ bar 693: %} R1 | | %{ bar 694: %} c'4 r2. | | %{ bar 695: %} R1 | | %{ bar 696: %} R1 | | %{ bar 697: %} e'4 r2. | | %{ bar 698: %} R1 | | %{ bar 699: %} g'4 r2. | | %{ bar 700: %} R1 | | %{ bar 701: %} d'2. c''4  ~ | | %{ bar 702: %} c''4 r2. | | %{ bar 703: %} R1 | | %{ bar 704: %} r2 d''8 r4 r8 | | %{ bar 705: %} R1 | | %{ bar 706: %} R1 | | %{ bar 707: %} a'4. b'4 r4 r8 | | %{ bar 708: %} R1 | | %{ bar 709: %} c'4 r2. | | %{ bar 710: %} R1 | | %{ bar 711: %} R1 | | %{ bar 712: %} e'4 r2. | | %{ bar 713: %} R1 | | %{ bar 714: %} g'4 r2. | | %{ bar 715: %} R1 | | %{ bar 716: %} d'2. c''4  ~ | | %{ bar 717: %} c''4 r2. | | %{ bar 718: %} R1 | | %{ bar 719: %} r2 d''8 r4 r8 | | %{ bar 720: %} R1 | | %{ bar 721: %} R1 | | %{ bar 722: %} a'4. b'4 r4 r8 | | %{ bar 723: %} R1 | | %{ bar 724: %} c'4 r2. | | %{ bar 725: %} R1 | | %{ bar 726: %} R1 | | %{ bar 727: %} e'4 r2. | | %{ bar 728: %} R1 | | %{ bar 729: %} g'4 r2. | | %{ bar 730: %} R1 | | %{ bar 731: %} d'2. c''4  ~ | | %{ bar 732: %} c''4 r2. | | %{ bar 733: %} R1 | | %{ bar 734: %} r2 d''8 r4 r8 | | %{ bar 735: %} R1 | | %{ bar 736: %} R1 | | %{ bar 737: %} a'4. b'4 r4 r8 | | %{ bar 738: %} R1 | | %{ bar 739: %} c'4 r2. | | %{ bar 740: %} R1 | | %{ bar 741: %} R1 | | %{ bar 742: %} e'4 r2. | | %{ bar 743: %} R1 | | %{ bar 744: %} g'4 r2. | | %{ bar 745: %} R1 | | %{ bar 746: %} d'2. c''4  ~ | | %{ bar 747: %} c''4 r2. | | %{ bar 748: %} R1 | | %{ bar 749: %} r2 d''8 r4 r8 | | %{ bar 750: %} R1 | | %{ bar 751: %} R1 | | %{ bar 752: %} a'4. b'4 r4 r8 | | %{ bar 753: %} R1 | | %{ bar 754: %} c'4 r2. | | %{ bar 755: %} R1 | | %{ bar 756: %} R1 | | %{ bar 757: %} e'4 r2. | | %{ bar 758: %} R1 | | %{ bar 759: %} g'4 r2. | | %{ bar 760: %} R1 | | %{ bar 761: %} d'2. c''4  ~ | | %{ bar 762: %} c''4 r2. | | %{ bar 763: %} R1 | | %{ bar 764: %} r2 d''8 r4 r8 | | %{ bar 765: %} R1 | | %{ bar 766: %} R1 | | %{ bar 767: %} a'4. b'4 r4 r8 | | %{ bar 768: %} R1 | | %{ bar 769: %} c'4 r2. | | %{ bar 770: %} R1 | | %{ bar 771: %} R1 | | %{ bar 772: %} e'4 r2. | | %{ bar 773: %} R1 | | %{ bar 774: %} g'4 r2. | | %{ bar 775: %} R1 | | %{ bar 776: %} d'2. c''4  ~ | | %{ bar 777: %} c''4 r2. | | %{ bar 778: %} R1 | | %{ bar 779: %} r2 d''8 r4 r8 | | %{ bar 780: %} R1 | | %{ bar 781: %} R1 | | %{ bar 782: %} a'4. b'4 r4 r8 | | %{ bar 783: %} R1 | | %{ bar 784: %} c'4 r2. | | %{ bar 785: %} R1 | | %{ bar 786: %} R1 | | %{ bar 787: %} e'4 r2. | | %{ bar 788: %} R1 | | %{ bar 789: %} g'4 r2. | | %{ bar 790: %} R1 | | %{ bar 791: %} d'2. c''4  ~ | | %{ bar 792: %} c''4 r2. | | %{ bar 793: %} R1 | | %{ bar 794: %} r2 d''8 r4 r8 | | %{ bar 795: %} R1 | | %{ bar 796: %} R1 | | %{ bar 797: %} a'4. b'4 r4 r8 | | %{ bar 798: %} R1 | | %{ bar 799: %} c'4 r2. | | %{ bar 800: %} R1 | | %{ bar 801: %} R1 | | %{ bar 802: %} e'4 r2. | | %{ bar 803: %} R1 | | %{ bar 804: %} g'4 r2. | | %{ bar 805: %} R1 | | %{ bar 806: %} d'2. c''4  ~ | | %{ bar 807: %} c''4 r2. | | %{ bar 808: %} R1 | | %{ bar 809: %} r2 d''8 r4 r8 | | %{ bar 810: %} R1 | | %{ bar 811: %} R1 | | %{ bar 812: %} a'4. b'4 r4 r8 | | %{ bar 813: %} R1 | | %{ bar 814: %} c'4 r2. | | %{ bar 815: %} R1 | | %{ bar 816: %} R1 | | %{ bar 817: %} e'4 r2. | | %{ bar 818: %} R1 | | %{ bar 819: %} g'4 r2. | | %{ bar 820: %} R1 | | %{ bar 821: %} d'2. c''4  ~ | | %{ bar 822: %} c''4 r2. | | %{ bar 823: %} R1 | | %{ bar 824: %} r2 d''8 r4 r8 | | %{ bar 825: %} R1 | | %{ bar 826: %} R1 | | %{ bar 827: %} a'4. b'4 r4 r8 | | %{ bar 828: %} R1 | | %{ bar 829: %} c'4 r2. | | %{ bar 830: %} R1 | | %{ bar 831: %} R1 | | %{ bar 832: %} e'4 r2. | | %{ bar 833: %} R1 | | %{ bar 834: %} g'4 r2. | | %{ bar 835: %} R1 | | %{ bar 836: %} d'2. c''4  ~ | | %{ bar 837: %} c''4 r2. | | %{ bar 838: %} R1 | | %{ bar 839: %} r2 d''8 r4 r8 | | %{ bar 840: %} R1 | | %{ bar 841: %} R1 | | %{ bar 842: %} a'4. b'4 r4 r8 | | %{ bar 843: %} R1 | | %{ bar 844: %} c'4 r2. | | %{ bar 845: %} R1 | | %{ bar 846: %} R1 | | %{ bar 847: %} e'4 r2. | | %{ bar 848: %} R1 | | %{ bar 849: %} g'4 r2. | | %{ bar 850: %} R1 | | %{ bar 851: %} d'2. c''4  ~ | | %{ bar 852: %} c''4 r2. | | %{ bar 853: %} R1 | | %{ bar 854: %} r2 d''8 r4 r8 | | %{ bar 855: %} R1 | | %{ bar 856: %} R1 | | %{ bar 857: %} a'4. b'4 r4 r8 | | %{ bar 858: %} R1 | | %{ bar 859: %} c'4 r2. | | %{ bar 860: %} R1 | | %{ bar 861: %} R1 | | %{ bar 862: %} e'4 r2. | | %{ bar 863: %} R1 | | %{ bar 864: %} g'4 r2. | | %{ bar 865: %} R1 | | %{ bar 866: %} d'2. c''4  ~ | | %{ bar 867: %} c''4 r2. | | %{ bar 868: %} R1 | | %{ bar 869: %} r2 d''8 r4 r8 | | %{ bar 870: %} R1 | | %{ bar 871: %} R1 | | %{ bar 872: %} a'4. b'4 r4 r8 | | %{ bar 873: %} R1 | | %{ bar 874: %} c'4 r2. | | %{ bar 875: %} R1 | | %{ bar 876: %} R1 | | %{ bar 877: %} e'4 r2. | | %{ bar 878: %} R1 | | %{ bar 879: %} g'4 r2. | | %{ bar 880: %} R1 | | %{ bar 881: %} d'2. c''4  ~ | | %{ bar 882: %} c''4 r2. | | %{ bar 883: %} R1 | | %{ bar 884: %} r2 d''8 r4 r8 | | %{ bar 885: %} R1 | | %{ bar 886: %} R1 | | %{ bar 887: %} a'4. b'4 r4 r8 | | %{ bar 888: %} R1 | | %{ bar 889: %} c'4 r2. | | %{ bar 890: %} R1 | | %{ bar 891: %} R1 | | %{ bar 892: %} e'4 r2. | | %{ bar 893: %} R1 | | %{ bar 894: %} g'4 r2. | | %{ bar 895: %} R1 | | %{ bar 896: %} d'2. c''4  ~ | | %{ bar 897: %} c''4 r2. | | %{ bar 898: %} R1 | | %{ bar 899: %} r2 d''8 r4 r8 | | %{ bar 900: %} R1 | | %{ bar 901: %} R1 | | %{ bar 902: %} a'4. b'4 r4 r8 | | %{ bar 903: %} R1 | | %{ bar 904: %} c'4 r2. | | %{ bar 905: %} R1 | | %{ bar 906: %} R1 | | %{ bar 907: %} e'4 r2. | | %{ bar 908: %} R1 | | %{ bar 909: %} g'4 r2. | | %{ bar 910: %} R1 | | %{ bar 911: %} d'2. c''4  ~ | | %{ bar 912: %} c''4 r2. | | %{ bar 913: %} R1 | | %{ bar 914: %} r2 d''8 r4 r8 | | %{ bar 915: %} R1 | | %{ bar 916: %} R1 | | %{ bar 917: %} a'4. b'4 r4 r8 | | %{ bar 918: %} R1 | | %{ bar 919: %} c'4 r2. | | %{ bar 920: %} R1 | | %{ bar 921: %} R1 | | %{ bar 922: %} e'4 r2. | | %{ bar 923: %} R1 | | %{ bar 924: %} g'4 r2. | | %{ bar 925: %} R1 | | %{ bar 926: %} d'2. c''4  ~ | | %{ bar 927: %} c''4 r2. | | %{ bar 928: %} R1 | | %{ bar 929: %} r2 d''8 r4 r8 | | %{ bar 930: %} R1 | | %{ bar 931: %} R1 | | %{ bar 932: %} a'4. b'4 r4 r8 | | %{ bar 933: %} R1 | | %{ bar 934: %} c'4 r2. | | %{ bar 935: %} R1 | | %{ bar 936: %} R1 | | %{ bar 937: %} e'4 r2. | | %{ bar 938: %} R1 | | %{ bar 939: %} g'4 r2. | | %{ bar 940: %} R1 | | %{ bar 941: %} d'2. c''4  ~ | | %{ bar 942: %} c''4 r2. | | %{ bar 943: %} R1 | | %{ bar 944: %} r2 d''8 r4 r8 | | %{ bar 945: %} R1 | | %{ bar 946: %} R1 | | %{ bar 947: %} a'4. b'4 r4 r8 | | %{ bar 948: %} R1 | | %{ bar 949: %} c'4 r2. | | %{ bar 950: %} R1 | | %{ bar 951: %} R1 | | %{ bar 952: %} e'4 r2. | | %{ bar 953: %} R1 | | %{ bar 954: %} g'4 r2. | | %{ bar 955: %} R1 | | %{ bar 956: %} d'2. c''4  ~ | | %{ bar 957: %} c''4 r2. | | %{ bar 958: %} R1 | | %{ bar 959: %} r2 d''8 r4 r8 | | %{ bar 960: %} R1 | | %{ bar 961: %} R1 | | %{ bar 962: %} a'4. b'4 r4 r8 | | %{ bar 963: %} R1 | | %{ bar 964: %} c'4 r2. | | %{ bar 965: %} R1 | | %{ bar 966: %} R1 | | %{ bar 967: %} e'4 r2. | | %{ bar 968: %} R1 | | %{ bar 969: %} g'4 r2. | | %{ bar 970: %} R1 | | %{ bar 971: %} d'2. c''4  ~ | | %{ bar 972: %} c''4 r2. | | %{ bar 973: %} R1 | | %{ bar 974: %} r2 d''8 r4 r8 | | %{ bar 975: %} R1 | | %{ bar 976: %} R1 | | %{ bar 977: %} a'4. b'4 r4 r8 | | %{ bar 978: %} R1 | | %{ bar 979: %} c'4 r2. | | %{ bar 980: %} R1 | | %{ bar 981: %} R1 | | %{ bar 982: %} e'4 r2. | | %{ bar 983: %} R1 | | %{ bar 984: %} g'4 r2. | | %{ bar 985: %} R1 | | %{ bar 986: %} d'2. c''4  ~ | | %{ bar 987: %} c''4 r2. | | %{ bar 988: %} R1 | | %{ bar 989: %} r2 d''8 r4 r8 | | %{ bar 990: %} R1 | | %{ bar 991: %} R1 | | %{ bar 992: %} a'4. b'4 r4 r8 | | %{ bar 993: %} R1 | | %{ bar 994: %} c'4 r2. | | %{ bar 995: %} R1 | | %{ bar 996: %} R1 | | %{ bar 997: %} e'4 r2. | | %{ bar 998: %} R1 | | %{ bar 999: %} g'4 r2. | | %{ bar 1000: %} R1 | | %{ bar 1001: %} d'2. c''4  ~ | | %{ bar 1002: %} c''4 r2. | | %{ bar 1003: %} R1 | | %{ bar 1004: %} r2 d''8 r4 r8 | | %{ bar 1005: %} R1 | | %{ bar 1006: %} R1 | | %{ bar 1007: %} a'4. b'4 r4 r8 | | %{ bar 1008: %} R1 | | %{ bar 1009: %} c'4 r2. | | %{ bar 1010: %} R1 | | %{ bar 1011: %} R1 | | %{ bar 1012: %} e'4 r2. | | %{ bar 1013: %} R1 | | %{ bar 1014: %} g'4 r2. | | %{ bar 1015: %} R1 | | %{ bar 1016: %} d'2. c''4  ~ | | %{ bar 1017: %} c''4 r2. | | %{ bar 1018: %} R1 | | %{ bar 1019: %} r2 d''8 r4 r8 | | %{ bar 1020: %} R1 | | %{ bar 1021: %} R1 | | %{ bar 1022: %} a'4. b'4 r4 r8 | | %{ bar 1023: %} R1 | | %{ bar 1024: %} c'4 r2. | | %{ bar 1025: %} R1 | | %{ bar 1026: %} R1 | | %{ bar 1027: %} e'4 r2. | | %{ bar 1028: %} R1 | | %{ bar 1029: %} g'4 r2. | | %{ bar 1030: %} R1 | | %{ bar 1031: %} d'2. c''4  ~ | | %{ bar 1032: %} c''4 r2. | | %{ bar 1033: %} R1 | | %{ bar 1034: %} r2 d''8 r4 r8 | | %{ bar 1035: %} R1 | | %{ bar 1036: %} R1 | | %{ bar 1037: %} a'4. b'4 r4 r8 | | %{ bar 1038: %} R1 | | %{ bar 1039: %} c'4 r2. | | %{ bar 1040: %} R1 | | %{ bar 1041: %} R1 | | %{ bar 1042: %} e'4 r2. | | %{ bar 1043: %} R1 | | %{ bar 1044: %} g'4 r2. | | %{ bar 1045: %} R1 | | %{ bar 1046: %} d'2. c''4  ~ | | %{ bar 1047: %} c''4 r2. | | %{ bar 1048: %} R1 | | %{ bar 1049: %} r2 d''8 r4 r8 | | %{ bar 1050: %} R1 | | %{ bar 1051: %} R1 | | %{ bar 1052: %} a'4. b'4 r4 r8 | | %{ bar 1053: %} R1 | | %{ bar 1054: %} c'4 r2. | | %{ bar 1055: %} R1 | | %{ bar 1056: %} R1 | | %{ bar 1057: %} e'4 r2. | | %{ bar 1058: %} R1 | | %{ bar 1059: %} g'4 r2. | | %{ bar 1060: %} R1 | | %{ bar 1061: %} d'2. c''4  ~ | | %{ bar 1062: %} c''4 r2. | | %{ bar 1063: %} R1 | | %{ bar 1064: %} r2 d''8 r4 r8 | | %{ bar 1065: %} R1 | | %{ bar 1066: %} R1 | | %{ bar 1067: %} a'4. b'4 r4 r8 | | %{ bar 1068: %} R1 | | %{ bar 1069: %} c'4 r2. | | %{ bar 1070: %} R1 | | %{ bar 1071: %} R1 | | %{ bar 1072: %} e'4 r2. | | %{ bar 1073: %} R1 | | %{ bar 1074: %} g'4 r2. | | %{ bar 1075: %} R1 | | %{ bar 1076: %} d'2. c''4  ~ | | %{ bar 1077: %} c''4 r2. | | %{ bar 1078: %} R1 | | %{ bar 1079: %} r2 d''8 r4 r8 | | %{ bar 1080: %} R1 | | %{ bar 1081: %} R1 | | %{ bar 1082: %} a'4. b'4 r4 r8 | | %{ bar 1083: %} R1 | | %{ bar 1084: %} c'4 r2. | | %{ bar 1085: %} R1 | | %{ bar 1086: %} R1 | | %{ bar 1087: %} e'4 r2. | | %{ bar 1088: %} R1 | | %{ bar 1089: %} g'4 r2. | | %{ bar 1090: %} R1 | | %{ bar 1091: %} d'2. c''4  ~ | | %{ bar 1092: %} c''4 r2. | | %{ bar 1093: %} R1 | | %{ bar 1094: %} r2 d''8 r4 r8 | | %{ bar 1095: %} R1 | | %{ bar 1096: %} R1 | | %{ bar 1097: %} a'4. b'4 r4 r8 | | %{ bar 1098: %} R1 | | %{ bar 1099: %} c'4 r2. | | %{ bar 1100: %} R1 | | %{ bar 1101: %} R1 | | %{ bar 1102: %} e'4 r2. | | %{ bar 1103: %} R1 | | %{ bar 1104: %} g'4 r2. | | %{ bar 1105: %} R1 | | %{ bar 1106: %} d'2. c''4  ~ | | %{ bar 1107: %} c''4 r2. | | %{ bar 1108: %} R1 | | %{ bar 1109: %} r2 d''8 r4 r8 | | %{ bar 1110: %} R1 | | %{ bar 1111: %} R1 | | %{ bar 1112: %} a'4. b'4 r4 r8 | | %{ bar 1113: %} R1 | | %{ bar 1114: %} c'4 r2. | | %{ bar 1115: %} R1 | | %{ bar 1116: %} R1 | | %{ bar 1117: %} e'4 r2. | | %{ bar 1118: %} R1 | | %{ bar 1119: %} g'4 r2. | | %{ bar 1120: %} R1 | | %{ bar 1121: %} d'2. c''4  ~ | | %{ bar 1122: %} c''4 r2. | | %{ bar 1123: %} R1 | | %{ bar 1124: %} r2 d''8 r4 r8 | | %{ bar 1125: %} R1 | | %{ bar 1126: %} R1 | | %{ bar 1127: %} a'4. b'4 r4 r8 | | %{ bar 1128: %} R1 | | %{ bar 1129: %} c'4 r2. | | %{ bar 1130: %} R1 | | %{ bar 1131: %} R1 | | %{ bar 1132: %} e'4 r2. | | %{ bar 1133: %} R1 | | %{ bar 1134: %} g'4 r2. | | %{ bar 1135: %} R1 | | %{ bar 1136: %} d'2. c''4  ~ | | %{ bar 1137: %} c''4 r2. | | %{ bar 1138: %} R1 | | %{ bar 1139: %} r2 d''8 r4 r8 | | %{ bar 1140: %} R1 | | %{ bar 1141: %} R1 | | %{ bar 1142: %} a'4. b'4 r4 r8 | | %{ bar 1143: %} R1 | | %{ bar 1144: %} c'4 r2. | | %{ bar 1145: %} R1 | | %{ bar 1146: %} R1 | | %{ bar 1147: %} e'4 r2. | | %{ bar 1148: %} R1 | | %{ bar 1149: %} g'4 r2. | | %{ bar 1150: %} R1 | | %{ bar 1151: %} d'2. c''4  ~ | | %{ bar 1152: %} c''4 r2. | | %{ bar 1153: %} R1 | | %{ bar 1154: %} r2 d''8 r4 r8 | | %{ bar 1155: %} R1 | | %{ bar 1156: %} R1 | | %{ bar 1157: %} a'4. b'4 r4 r8 | | %{ bar 1158: %} R1 | | %{ bar 1159: %} c'4 r2. | | %{ bar 1160: %} R1 | | %{ bar 1161: %} R1 | | %{ bar 1162: %} e'4 r2. | | %{ bar 1163: %} R1 | | %{ bar 1164: %} g'4 r2. | | %{ bar 1165: %} R1 | | %{ bar 1166: %} d'2. c''4  ~ | | %{ bar 1167: %} c''4 r2. | | %{ bar 1168: %} R1 | | %{ bar 1169: %} r2 d''8 r4 r8 | | %{ bar 1170: %} R1 | | %{ bar 1171: %} R1 | | %{ bar 1172: %} a'4. b'4 r4 r8 | | %{ bar 1173: %} R1 | | %{ bar 1174: %} c'4 r2. | | %{ bar 1175: %} R1 | | %{ bar 1176: %} R1 | | %{ bar 1177: %} e'4 r2. | | %{ bar 1178: %} R1 | | %{ bar 1179: %} g'4 r2. | | %{ bar 1180: %} r1 | } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
