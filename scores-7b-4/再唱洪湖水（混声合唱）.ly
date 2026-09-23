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
subtitle=再唱洪湖水
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q5 q6 0 0 | 0 0 0 0 |
q1 q3 q5 q6 0 0 | 0 0 0 0 |
q1 q3 q5 q6 0 0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
q1 q3 q6 0 0 q0 | 0 0 0 0 |
q1 q3 q4 0 0 q0 | 0 0 0 0 |
q1 q3 q5 0 0 q0 | 0 0 0 0 |
q1. q2 - 0 q0. | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0 | 0 0 0 0 |
q1 - q2 - 0
7 q2 - 0 q0 | 0 0 0 0 |
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
     \time 4/4  \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
 \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
 \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
 \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 15: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 16: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 18: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 19: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 20: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 21: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 22: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 23: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 24: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 25: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 26: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 27: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 28: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 29: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 31: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 32: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 33: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 34: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 35: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 36: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 37: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 38: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 39: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 40: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 41: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 42: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 43: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 44: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 45: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 46: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 47: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 48: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 49: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 50: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 51: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 52: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 53: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 54: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 55: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 56: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 57: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 58: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 59: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 60: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 61: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 62: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 63: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 64: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 65: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 66: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 67: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 68: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 69: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 70: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 71: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 72: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 73: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 74: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 75: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 76: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 77: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 78: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 79: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 80: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 81: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 82: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 83: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 84: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 85: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 86: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 87: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 88: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 89: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 90: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 91: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 92: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 93: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 94: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 95: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 96: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 97: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 98: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 99: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 100: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 101: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 102: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 103: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 104: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 105: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 106: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 107: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 108: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 109: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 111: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 112: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 113: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 114: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 115: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 116: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 117: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 118: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 119: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 120: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 121: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 122: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 123: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 124: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 125: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 126: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 127: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 128: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 129: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 130: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 131: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 132: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 133: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 134: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 135: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 136: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 137: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 138: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 139: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 140: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 141: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 142: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 143: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 144: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 145: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 146: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 147: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 148: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 149: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 150: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 151: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 152: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 153: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 154: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 155: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 156: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 157: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 158: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 159: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 160: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 161: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 162: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 163: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 164: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 165: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 166: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 167: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 168: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 169: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 170: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 171: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 172: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 173: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 174: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 175: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 176: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 177: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 178: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 179: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 180: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 181: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 182: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 183: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 184: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 185: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 186: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 187: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 188: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 189: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 190: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 191: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 192: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 193: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 194: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 195: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 196: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 197: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 198: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 199: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 200: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 201: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 202: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 203: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 204: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 205: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 206: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 207: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 208: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 209: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 210: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 211: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 212: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 213: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 214: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 215: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 216: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 217: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 218: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 219: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 220: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 221: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 222: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 223: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 224: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 225: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 226: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 227: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 228: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 229: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 230: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 231: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 232: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 233: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 234: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 235: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 236: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 237: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 238: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 239: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 240: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 241: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 242: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 243: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 244: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 245: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 246: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 247: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 248: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 249: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 250: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 251: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 252: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 253: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 254: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 255: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 256: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 257: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 258: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 259: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 260: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 261: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 262: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 263: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 264: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 265: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 266: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 267: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 268: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 269: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 270: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 271: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 272: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 273: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 274: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 275: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 276: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 277: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 278: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 279: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 280: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 281: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 282: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 283: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 284: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 285: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 286: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 287: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 288: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 289: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 290: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 291: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 292: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 293: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 294: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 295: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 296: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 297: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 298: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 299: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 300: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 301: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 302: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 303: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 304: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 305: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 306: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 307: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 308: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 309: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 310: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 311: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 312: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 313: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 314: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 315: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 316: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 317: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 318: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 319: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 320: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 321: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 322: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 323: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 324: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 325: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 326: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 327: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 328: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 329: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 330: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 331: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 332: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 333: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 334: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 335: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 336: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 337: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 338: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 339: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 340: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 341: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 342: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 343: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 344: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 345: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 346: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 347: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 348: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 349: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 350: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 351: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 352: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 353: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 354: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 355: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 356: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 357: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 358: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 359: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 360: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 361: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 362: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 363: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 364: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 365: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 366: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 367: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 368: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 369: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 370: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 371: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 372: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 373: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 374: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 375: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 376: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 377: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 378: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 379: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 380: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 381: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 382: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 383: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 384: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 385: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 386: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 387: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 388: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 389: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 390: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 391: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 392: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 393: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 394: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 395: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 396: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 397: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 398: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 399: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 400: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 401: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 402: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 403: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 404: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 405: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 406: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 407: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 408: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 409: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 410: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 411: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 412: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 413: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 414: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 415: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 416: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 417: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 418: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 419: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 420: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 421: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 422: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 423: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 424: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 425: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 426: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 427: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 428: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 429: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 430: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 431: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 432: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 433: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 434: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 435: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 436: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 437: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 438: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 439: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 440: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 441: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 442: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 443: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 444: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 445: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 446: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 447: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 448: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 449: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 450: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 451: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 452: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 453: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 454: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 455: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 456: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 457: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 458: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 459: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 460: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 461: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 462: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 463: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 464: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 465: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 466: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 467: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 468: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 469: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 470: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 471: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 472: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 473: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 474: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 475: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 476: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 477: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 478: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 479: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 480: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 481: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 482: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 483: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 484: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 485: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 486: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 487: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 488: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 489: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 490: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 491: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 492: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 493: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 494: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 495: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 496: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 497: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 498: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 499: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 500: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 501: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 502: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 503: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 504: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 505: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 506: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 507: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 508: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 509: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 510: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 511: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 512: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 513: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 514: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 515: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 516: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 517: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 518: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 519: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 520: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 521: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 522: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 523: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 524: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 525: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 526: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 527: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 528: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 529: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 530: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 531: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 532: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 533: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 534: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 535: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 536: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 537: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 538: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 539: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 540: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 541: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 542: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 543: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 544: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 545: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 546: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 547: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 548: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 549: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 550: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 551: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 552: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 553: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 554: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 555: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 556: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 557: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 558: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 559: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 560: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 561: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 562: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 563: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 564: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 565: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 566: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 567: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 568: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 569: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 570: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 571: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 572: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 573: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 574: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 575: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 576: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 577: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 578: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 579: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 580: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 581: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 582: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 583: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 584: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 585: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 586: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 587: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 588: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 589: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 590: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 591: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 592: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 593: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 594: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 595: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 596: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 597: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 598: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 599: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 600: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 601: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 602: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 603: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 604: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 605: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 606: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 607: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 608: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 609: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 610: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 611: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 612: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 613: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 614: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 615: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 616: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 617: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 618: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 619: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 620: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 621: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 622: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 623: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 624: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 625: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 626: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 627: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 628: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 629: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 630: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 631: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 632: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 633: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 634: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 635: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 636: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 637: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 638: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 639: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 640: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 641: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 642: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 643: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 644: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 645: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 646: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 647: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 648: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 649: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 650: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 651: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 652: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 653: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 654: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 655: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 656: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 657: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 658: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 659: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 660: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 661: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 662: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 663: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 664: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 665: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 666: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 667: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 668: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 669: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 670: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 671: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 672: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 673: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 674: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 675: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 676: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 677: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 678: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 679: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 680: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 681: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 682: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 683: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 684: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 685: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 686: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 687: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 688: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 689: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 690: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 691: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 692: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 693: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 694: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 695: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 696: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 697: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 698: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 699: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 700: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 701: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 702: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 703: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 704: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 705: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 706: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 707: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 708: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 709: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 710: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 711: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 712: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 713: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 714: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 715: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 716: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 717: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 718: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 719: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 720: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 721: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 722: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 723: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 724: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 725: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 726: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 727: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 728: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 729: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 730: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 731: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 732: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 733: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 734: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 735: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 736: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 737: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 738: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 739: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 740: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 741: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 742: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 743: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 744: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 745: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 746: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 747: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 748: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 749: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 750: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 751: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 752: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 753: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 754: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 755: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 756: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 757: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 758: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 759: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 760: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 761: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 762: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 763: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 764: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 765: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 766: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 767: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 768: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 769: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 770: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 771: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 772: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 773: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 774: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 775: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 776: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 777: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 778: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 779: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 780: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 781: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 782: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 783: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 784: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 785: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 786: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 787: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 788: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 789: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 790: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 791: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 792: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 793: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 794: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 795: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 796: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 797: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 798: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 799: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 800: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 801: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 802: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 803: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 804: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 805: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 806: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 807: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 808: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 809: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 810: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 811: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 812: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 813: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 814: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 815: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 816: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 817: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 818: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 819: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 820: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 821: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 822: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 823: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 824: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 825: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 826: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 827: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 828: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 829: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 830: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 831: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 832: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 833: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 834: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 835: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 836: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 837: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 838: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 839: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 840: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 841: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 842: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 843: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 844: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 845: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 846: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 847: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 848: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 849: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 850: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 851: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 852: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 853: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 854: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 855: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 856: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 857: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 858: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 859: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 860: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 861: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 862: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 863: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 864: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 865: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 866: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 867: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 868: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 869: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 870: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 871: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 872: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 873: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 874: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 875: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 876: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 877: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 878: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 879: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 880: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 881: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 882: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 883: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 884: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 885: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4  \note-mod "0" r4 | %{ bar 886: %}
 \note-mod "7" b'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 887: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="再唱洪湖水"
}
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
    \new Staff { \new Voice="X" { \time 4/4 b'4 d'8  ~ d'4 r4 r8 | | %{ bar 2: %} R1 | | %{ bar 3: %} c'8 e'8 g'8 a'8 r2 | | %{ bar 4: %} R1 | | %{ bar 5: %} c'8 e'8 g'8 a'8 r2 | | %{ bar 6: %} R1 | | %{ bar 7: %} c'8 e'8 g'8 a'8 r2 | | %{ bar 8: %} R1 | | %{ bar 9: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 12: %} R1 | | %{ bar 13: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 14: %} R1 | | %{ bar 15: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 16: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 17: %} R1 | | %{ bar 18: %} c'8 e'8 f'8 r2 r8 | | %{ bar 19: %} R1 | | %{ bar 20: %} c'8 e'8 f'8 r2 r8 | | %{ bar 21: %} R1 | | %{ bar 22: %} c'8 e'8 g'8 r2 r8 | | %{ bar 23: %} R1 | | %{ bar 24: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 25: %} R1 | | %{ bar 26: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 27: %} R1 | | %{ bar 28: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 29: %} R1 | | %{ bar 30: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 31: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 32: %} R1 | | %{ bar 33: %} c'8 e'8 a'8 r2 r8 | | %{ bar 34: %} R1 | | %{ bar 35: %} c'8 e'8 f'8 r2 r8 | | %{ bar 36: %} R1 | | %{ bar 37: %} c'8 e'8 g'8 r2 r8 | | %{ bar 38: %} R1 | | %{ bar 39: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 40: %} R1 | | %{ bar 41: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 42: %} R1 | | %{ bar 43: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 44: %} R1 | | %{ bar 45: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 46: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 47: %} R1 | | %{ bar 48: %} c'8 e'8 a'8 r2 r8 | | %{ bar 49: %} R1 | | %{ bar 50: %} c'8 e'8 f'8 r2 r8 | | %{ bar 51: %} R1 | | %{ bar 52: %} c'8 e'8 g'8 r2 r8 | | %{ bar 53: %} R1 | | %{ bar 54: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 55: %} R1 | | %{ bar 56: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 57: %} R1 | | %{ bar 58: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 59: %} R1 | | %{ bar 60: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 61: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 62: %} R1 | | %{ bar 63: %} c'8 e'8 a'8 r2 r8 | | %{ bar 64: %} R1 | | %{ bar 65: %} c'8 e'8 f'8 r2 r8 | | %{ bar 66: %} R1 | | %{ bar 67: %} c'8 e'8 g'8 r2 r8 | | %{ bar 68: %} R1 | | %{ bar 69: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 70: %} R1 | | %{ bar 71: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 72: %} R1 | | %{ bar 73: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 74: %} R1 | | %{ bar 75: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 76: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 77: %} R1 | | %{ bar 78: %} c'8 e'8 a'8 r2 r8 | | %{ bar 79: %} R1 | | %{ bar 80: %} c'8 e'8 f'8 r2 r8 | | %{ bar 81: %} R1 | | %{ bar 82: %} c'8 e'8 g'8 r2 r8 | | %{ bar 83: %} R1 | | %{ bar 84: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 85: %} R1 | | %{ bar 86: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 87: %} R1 | | %{ bar 88: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 89: %} R1 | | %{ bar 90: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 91: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 92: %} R1 | | %{ bar 93: %} c'8 e'8 a'8 r2 r8 | | %{ bar 94: %} R1 | | %{ bar 95: %} c'8 e'8 f'8 r2 r8 | | %{ bar 96: %} R1 | | %{ bar 97: %} c'8 e'8 g'8 r2 r8 | | %{ bar 98: %} R1 | | %{ bar 99: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 100: %} R1 | | %{ bar 101: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 102: %} R1 | | %{ bar 103: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 104: %} R1 | | %{ bar 105: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 106: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 107: %} R1 | | %{ bar 108: %} c'8 e'8 a'8 r2 r8 | | %{ bar 109: %} R1 | | %{ bar 110: %} c'8 e'8 f'8 r2 r8 | | %{ bar 111: %} R1 | | %{ bar 112: %} c'8 e'8 g'8 r2 r8 | | %{ bar 113: %} R1 | | %{ bar 114: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 115: %} R1 | | %{ bar 116: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 117: %} R1 | | %{ bar 118: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 119: %} R1 | | %{ bar 120: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 121: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 122: %} R1 | | %{ bar 123: %} c'8 e'8 a'8 r2 r8 | | %{ bar 124: %} R1 | | %{ bar 125: %} c'8 e'8 f'8 r2 r8 | | %{ bar 126: %} R1 | | %{ bar 127: %} c'8 e'8 g'8 r2 r8 | | %{ bar 128: %} R1 | | %{ bar 129: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 130: %} R1 | | %{ bar 131: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 132: %} R1 | | %{ bar 133: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 134: %} R1 | | %{ bar 135: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 136: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 137: %} R1 | | %{ bar 138: %} c'8 e'8 a'8 r2 r8 | | %{ bar 139: %} R1 | | %{ bar 140: %} c'8 e'8 f'8 r2 r8 | | %{ bar 141: %} R1 | | %{ bar 142: %} c'8 e'8 g'8 r2 r8 | | %{ bar 143: %} R1 | | %{ bar 144: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 145: %} R1 | | %{ bar 146: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 147: %} R1 | | %{ bar 148: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 149: %} R1 | | %{ bar 150: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 151: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 152: %} R1 | | %{ bar 153: %} c'8 e'8 a'8 r2 r8 | | %{ bar 154: %} R1 | | %{ bar 155: %} c'8 e'8 f'8 r2 r8 | | %{ bar 156: %} R1 | | %{ bar 157: %} c'8 e'8 g'8 r2 r8 | | %{ bar 158: %} R1 | | %{ bar 159: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 160: %} R1 | | %{ bar 161: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 162: %} R1 | | %{ bar 163: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 164: %} R1 | | %{ bar 165: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 166: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 167: %} R1 | | %{ bar 168: %} c'8 e'8 a'8 r2 r8 | | %{ bar 169: %} R1 | | %{ bar 170: %} c'8 e'8 f'8 r2 r8 | | %{ bar 171: %} R1 | | %{ bar 172: %} c'8 e'8 g'8 r2 r8 | | %{ bar 173: %} R1 | | %{ bar 174: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 175: %} R1 | | %{ bar 176: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 177: %} R1 | | %{ bar 178: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 179: %} R1 | | %{ bar 180: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 181: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 182: %} R1 | | %{ bar 183: %} c'8 e'8 a'8 r2 r8 | | %{ bar 184: %} R1 | | %{ bar 185: %} c'8 e'8 f'8 r2 r8 | | %{ bar 186: %} R1 | | %{ bar 187: %} c'8 e'8 g'8 r2 r8 | | %{ bar 188: %} R1 | | %{ bar 189: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 190: %} R1 | | %{ bar 191: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 192: %} R1 | | %{ bar 193: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 194: %} R1 | | %{ bar 195: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 196: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 197: %} R1 | | %{ bar 198: %} c'8 e'8 a'8 r2 r8 | | %{ bar 199: %} R1 | | %{ bar 200: %} c'8 e'8 f'8 r2 r8 | | %{ bar 201: %} R1 | | %{ bar 202: %} c'8 e'8 g'8 r2 r8 | | %{ bar 203: %} R1 | | %{ bar 204: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 205: %} R1 | | %{ bar 206: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 207: %} R1 | | %{ bar 208: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 209: %} R1 | | %{ bar 210: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 211: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 212: %} R1 | | %{ bar 213: %} c'8 e'8 a'8 r2 r8 | | %{ bar 214: %} R1 | | %{ bar 215: %} c'8 e'8 f'8 r2 r8 | | %{ bar 216: %} R1 | | %{ bar 217: %} c'8 e'8 g'8 r2 r8 | | %{ bar 218: %} R1 | | %{ bar 219: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 220: %} R1 | | %{ bar 221: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 222: %} R1 | | %{ bar 223: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 224: %} R1 | | %{ bar 225: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 226: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 227: %} R1 | | %{ bar 228: %} c'8 e'8 a'8 r2 r8 | | %{ bar 229: %} R1 | | %{ bar 230: %} c'8 e'8 f'8 r2 r8 | | %{ bar 231: %} R1 | | %{ bar 232: %} c'8 e'8 g'8 r2 r8 | | %{ bar 233: %} R1 | | %{ bar 234: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 235: %} R1 | | %{ bar 236: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 237: %} R1 | | %{ bar 238: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 239: %} R1 | | %{ bar 240: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 241: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 242: %} R1 | | %{ bar 243: %} c'8 e'8 a'8 r2 r8 | | %{ bar 244: %} R1 | | %{ bar 245: %} c'8 e'8 f'8 r2 r8 | | %{ bar 246: %} R1 | | %{ bar 247: %} c'8 e'8 g'8 r2 r8 | | %{ bar 248: %} R1 | | %{ bar 249: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 250: %} R1 | | %{ bar 251: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 252: %} R1 | | %{ bar 253: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 254: %} R1 | | %{ bar 255: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 256: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 257: %} R1 | | %{ bar 258: %} c'8 e'8 a'8 r2 r8 | | %{ bar 259: %} R1 | | %{ bar 260: %} c'8 e'8 f'8 r2 r8 | | %{ bar 261: %} R1 | | %{ bar 262: %} c'8 e'8 g'8 r2 r8 | | %{ bar 263: %} R1 | | %{ bar 264: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 265: %} R1 | | %{ bar 266: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 267: %} R1 | | %{ bar 268: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 269: %} R1 | | %{ bar 270: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 271: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 272: %} R1 | | %{ bar 273: %} c'8 e'8 a'8 r2 r8 | | %{ bar 274: %} R1 | | %{ bar 275: %} c'8 e'8 f'8 r2 r8 | | %{ bar 276: %} R1 | | %{ bar 277: %} c'8 e'8 g'8 r2 r8 | | %{ bar 278: %} R1 | | %{ bar 279: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 280: %} R1 | | %{ bar 281: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 282: %} R1 | | %{ bar 283: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 284: %} R1 | | %{ bar 285: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 286: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 287: %} R1 | | %{ bar 288: %} c'8 e'8 a'8 r2 r8 | | %{ bar 289: %} R1 | | %{ bar 290: %} c'8 e'8 f'8 r2 r8 | | %{ bar 291: %} R1 | | %{ bar 292: %} c'8 e'8 g'8 r2 r8 | | %{ bar 293: %} R1 | | %{ bar 294: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 295: %} R1 | | %{ bar 296: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 297: %} R1 | | %{ bar 298: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 299: %} R1 | | %{ bar 300: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 301: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 302: %} R1 | | %{ bar 303: %} c'8 e'8 a'8 r2 r8 | | %{ bar 304: %} R1 | | %{ bar 305: %} c'8 e'8 f'8 r2 r8 | | %{ bar 306: %} R1 | | %{ bar 307: %} c'8 e'8 g'8 r2 r8 | | %{ bar 308: %} R1 | | %{ bar 309: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 310: %} R1 | | %{ bar 311: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 312: %} R1 | | %{ bar 313: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 314: %} R1 | | %{ bar 315: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 316: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 317: %} R1 | | %{ bar 318: %} c'8 e'8 a'8 r2 r8 | | %{ bar 319: %} R1 | | %{ bar 320: %} c'8 e'8 f'8 r2 r8 | | %{ bar 321: %} R1 | | %{ bar 322: %} c'8 e'8 g'8 r2 r8 | | %{ bar 323: %} R1 | | %{ bar 324: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 325: %} R1 | | %{ bar 326: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 327: %} R1 | | %{ bar 328: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 329: %} R1 | | %{ bar 330: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 331: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 332: %} R1 | | %{ bar 333: %} c'8 e'8 a'8 r2 r8 | | %{ bar 334: %} R1 | | %{ bar 335: %} c'8 e'8 f'8 r2 r8 | | %{ bar 336: %} R1 | | %{ bar 337: %} c'8 e'8 g'8 r2 r8 | | %{ bar 338: %} R1 | | %{ bar 339: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 340: %} R1 | | %{ bar 341: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 342: %} R1 | | %{ bar 343: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 344: %} R1 | | %{ bar 345: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 346: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 347: %} R1 | | %{ bar 348: %} c'8 e'8 a'8 r2 r8 | | %{ bar 349: %} R1 | | %{ bar 350: %} c'8 e'8 f'8 r2 r8 | | %{ bar 351: %} R1 | | %{ bar 352: %} c'8 e'8 g'8 r2 r8 | | %{ bar 353: %} R1 | | %{ bar 354: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 355: %} R1 | | %{ bar 356: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 357: %} R1 | | %{ bar 358: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 359: %} R1 | | %{ bar 360: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 361: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 362: %} R1 | | %{ bar 363: %} c'8 e'8 a'8 r2 r8 | | %{ bar 364: %} R1 | | %{ bar 365: %} c'8 e'8 f'8 r2 r8 | | %{ bar 366: %} R1 | | %{ bar 367: %} c'8 e'8 g'8 r2 r8 | | %{ bar 368: %} R1 | | %{ bar 369: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 370: %} R1 | | %{ bar 371: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 372: %} R1 | | %{ bar 373: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 374: %} R1 | | %{ bar 375: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 376: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 377: %} R1 | | %{ bar 378: %} c'8 e'8 a'8 r2 r8 | | %{ bar 379: %} R1 | | %{ bar 380: %} c'8 e'8 f'8 r2 r8 | | %{ bar 381: %} R1 | | %{ bar 382: %} c'8 e'8 g'8 r2 r8 | | %{ bar 383: %} R1 | | %{ bar 384: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 385: %} R1 | | %{ bar 386: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 387: %} R1 | | %{ bar 388: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 389: %} R1 | | %{ bar 390: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 391: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 392: %} R1 | | %{ bar 393: %} c'8 e'8 a'8 r2 r8 | | %{ bar 394: %} R1 | | %{ bar 395: %} c'8 e'8 f'8 r2 r8 | | %{ bar 396: %} R1 | | %{ bar 397: %} c'8 e'8 g'8 r2 r8 | | %{ bar 398: %} R1 | | %{ bar 399: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 400: %} R1 | | %{ bar 401: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 402: %} R1 | | %{ bar 403: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 404: %} R1 | | %{ bar 405: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 406: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 407: %} R1 | | %{ bar 408: %} c'8 e'8 a'8 r2 r8 | | %{ bar 409: %} R1 | | %{ bar 410: %} c'8 e'8 f'8 r2 r8 | | %{ bar 411: %} R1 | | %{ bar 412: %} c'8 e'8 g'8 r2 r8 | | %{ bar 413: %} R1 | | %{ bar 414: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 415: %} R1 | | %{ bar 416: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 417: %} R1 | | %{ bar 418: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 419: %} R1 | | %{ bar 420: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 421: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 422: %} R1 | | %{ bar 423: %} c'8 e'8 a'8 r2 r8 | | %{ bar 424: %} R1 | | %{ bar 425: %} c'8 e'8 f'8 r2 r8 | | %{ bar 426: %} R1 | | %{ bar 427: %} c'8 e'8 g'8 r2 r8 | | %{ bar 428: %} R1 | | %{ bar 429: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 430: %} R1 | | %{ bar 431: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 432: %} R1 | | %{ bar 433: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 434: %} R1 | | %{ bar 435: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 436: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 437: %} R1 | | %{ bar 438: %} c'8 e'8 a'8 r2 r8 | | %{ bar 439: %} R1 | | %{ bar 440: %} c'8 e'8 f'8 r2 r8 | | %{ bar 441: %} R1 | | %{ bar 442: %} c'8 e'8 g'8 r2 r8 | | %{ bar 443: %} R1 | | %{ bar 444: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 445: %} R1 | | %{ bar 446: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 447: %} R1 | | %{ bar 448: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 449: %} R1 | | %{ bar 450: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 451: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 452: %} R1 | | %{ bar 453: %} c'8 e'8 a'8 r2 r8 | | %{ bar 454: %} R1 | | %{ bar 455: %} c'8 e'8 f'8 r2 r8 | | %{ bar 456: %} R1 | | %{ bar 457: %} c'8 e'8 g'8 r2 r8 | | %{ bar 458: %} R1 | | %{ bar 459: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 460: %} R1 | | %{ bar 461: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 462: %} R1 | | %{ bar 463: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 464: %} R1 | | %{ bar 465: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 466: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 467: %} R1 | | %{ bar 468: %} c'8 e'8 a'8 r2 r8 | | %{ bar 469: %} R1 | | %{ bar 470: %} c'8 e'8 f'8 r2 r8 | | %{ bar 471: %} R1 | | %{ bar 472: %} c'8 e'8 g'8 r2 r8 | | %{ bar 473: %} R1 | | %{ bar 474: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 475: %} R1 | | %{ bar 476: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 477: %} R1 | | %{ bar 478: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 479: %} R1 | | %{ bar 480: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 481: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 482: %} R1 | | %{ bar 483: %} c'8 e'8 a'8 r2 r8 | | %{ bar 484: %} R1 | | %{ bar 485: %} c'8 e'8 f'8 r2 r8 | | %{ bar 486: %} R1 | | %{ bar 487: %} c'8 e'8 g'8 r2 r8 | | %{ bar 488: %} R1 | | %{ bar 489: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 490: %} R1 | | %{ bar 491: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 492: %} R1 | | %{ bar 493: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 494: %} R1 | | %{ bar 495: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 496: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 497: %} R1 | | %{ bar 498: %} c'8 e'8 a'8 r2 r8 | | %{ bar 499: %} R1 | | %{ bar 500: %} c'8 e'8 f'8 r2 r8 | | %{ bar 501: %} R1 | | %{ bar 502: %} c'8 e'8 g'8 r2 r8 | | %{ bar 503: %} R1 | | %{ bar 504: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 505: %} R1 | | %{ bar 506: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 507: %} R1 | | %{ bar 508: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 509: %} R1 | | %{ bar 510: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 511: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 512: %} R1 | | %{ bar 513: %} c'8 e'8 a'8 r2 r8 | | %{ bar 514: %} R1 | | %{ bar 515: %} c'8 e'8 f'8 r2 r8 | | %{ bar 516: %} R1 | | %{ bar 517: %} c'8 e'8 g'8 r2 r8 | | %{ bar 518: %} R1 | | %{ bar 519: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 520: %} R1 | | %{ bar 521: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 522: %} R1 | | %{ bar 523: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 524: %} R1 | | %{ bar 525: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 526: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 527: %} R1 | | %{ bar 528: %} c'8 e'8 a'8 r2 r8 | | %{ bar 529: %} R1 | | %{ bar 530: %} c'8 e'8 f'8 r2 r8 | | %{ bar 531: %} R1 | | %{ bar 532: %} c'8 e'8 g'8 r2 r8 | | %{ bar 533: %} R1 | | %{ bar 534: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 535: %} R1 | | %{ bar 536: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 537: %} R1 | | %{ bar 538: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 539: %} R1 | | %{ bar 540: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 541: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 542: %} R1 | | %{ bar 543: %} c'8 e'8 a'8 r2 r8 | | %{ bar 544: %} R1 | | %{ bar 545: %} c'8 e'8 f'8 r2 r8 | | %{ bar 546: %} R1 | | %{ bar 547: %} c'8 e'8 g'8 r2 r8 | | %{ bar 548: %} R1 | | %{ bar 549: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 550: %} R1 | | %{ bar 551: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 552: %} R1 | | %{ bar 553: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 554: %} R1 | | %{ bar 555: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 556: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 557: %} R1 | | %{ bar 558: %} c'8 e'8 a'8 r2 r8 | | %{ bar 559: %} R1 | | %{ bar 560: %} c'8 e'8 f'8 r2 r8 | | %{ bar 561: %} R1 | | %{ bar 562: %} c'8 e'8 g'8 r2 r8 | | %{ bar 563: %} R1 | | %{ bar 564: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 565: %} R1 | | %{ bar 566: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 567: %} R1 | | %{ bar 568: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 569: %} R1 | | %{ bar 570: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 571: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 572: %} R1 | | %{ bar 573: %} c'8 e'8 a'8 r2 r8 | | %{ bar 574: %} R1 | | %{ bar 575: %} c'8 e'8 f'8 r2 r8 | | %{ bar 576: %} R1 | | %{ bar 577: %} c'8 e'8 g'8 r2 r8 | | %{ bar 578: %} R1 | | %{ bar 579: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 580: %} R1 | | %{ bar 581: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 582: %} R1 | | %{ bar 583: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 584: %} R1 | | %{ bar 585: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 586: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 587: %} R1 | | %{ bar 588: %} c'8 e'8 a'8 r2 r8 | | %{ bar 589: %} R1 | | %{ bar 590: %} c'8 e'8 f'8 r2 r8 | | %{ bar 591: %} R1 | | %{ bar 592: %} c'8 e'8 g'8 r2 r8 | | %{ bar 593: %} R1 | | %{ bar 594: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 595: %} R1 | | %{ bar 596: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 597: %} R1 | | %{ bar 598: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 599: %} R1 | | %{ bar 600: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 601: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 602: %} R1 | | %{ bar 603: %} c'8 e'8 a'8 r2 r8 | | %{ bar 604: %} R1 | | %{ bar 605: %} c'8 e'8 f'8 r2 r8 | | %{ bar 606: %} R1 | | %{ bar 607: %} c'8 e'8 g'8 r2 r8 | | %{ bar 608: %} R1 | | %{ bar 609: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 610: %} R1 | | %{ bar 611: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 612: %} R1 | | %{ bar 613: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 614: %} R1 | | %{ bar 615: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 616: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 617: %} R1 | | %{ bar 618: %} c'8 e'8 a'8 r2 r8 | | %{ bar 619: %} R1 | | %{ bar 620: %} c'8 e'8 f'8 r2 r8 | | %{ bar 621: %} R1 | | %{ bar 622: %} c'8 e'8 g'8 r2 r8 | | %{ bar 623: %} R1 | | %{ bar 624: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 625: %} R1 | | %{ bar 626: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 627: %} R1 | | %{ bar 628: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 629: %} R1 | | %{ bar 630: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 631: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 632: %} R1 | | %{ bar 633: %} c'8 e'8 a'8 r2 r8 | | %{ bar 634: %} R1 | | %{ bar 635: %} c'8 e'8 f'8 r2 r8 | | %{ bar 636: %} R1 | | %{ bar 637: %} c'8 e'8 g'8 r2 r8 | | %{ bar 638: %} R1 | | %{ bar 639: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 640: %} R1 | | %{ bar 641: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 642: %} R1 | | %{ bar 643: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 644: %} R1 | | %{ bar 645: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 646: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 647: %} R1 | | %{ bar 648: %} c'8 e'8 a'8 r2 r8 | | %{ bar 649: %} R1 | | %{ bar 650: %} c'8 e'8 f'8 r2 r8 | | %{ bar 651: %} R1 | | %{ bar 652: %} c'8 e'8 g'8 r2 r8 | | %{ bar 653: %} R1 | | %{ bar 654: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 655: %} R1 | | %{ bar 656: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 657: %} R1 | | %{ bar 658: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 659: %} R1 | | %{ bar 660: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 661: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 662: %} R1 | | %{ bar 663: %} c'8 e'8 a'8 r2 r8 | | %{ bar 664: %} R1 | | %{ bar 665: %} c'8 e'8 f'8 r2 r8 | | %{ bar 666: %} R1 | | %{ bar 667: %} c'8 e'8 g'8 r2 r8 | | %{ bar 668: %} R1 | | %{ bar 669: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 670: %} R1 | | %{ bar 671: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 672: %} R1 | | %{ bar 673: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 674: %} R1 | | %{ bar 675: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 676: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 677: %} R1 | | %{ bar 678: %} c'8 e'8 a'8 r2 r8 | | %{ bar 679: %} R1 | | %{ bar 680: %} c'8 e'8 f'8 r2 r8 | | %{ bar 681: %} R1 | | %{ bar 682: %} c'8 e'8 g'8 r2 r8 | | %{ bar 683: %} R1 | | %{ bar 684: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 685: %} R1 | | %{ bar 686: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 687: %} R1 | | %{ bar 688: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 689: %} R1 | | %{ bar 690: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 691: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 692: %} R1 | | %{ bar 693: %} c'8 e'8 a'8 r2 r8 | | %{ bar 694: %} R1 | | %{ bar 695: %} c'8 e'8 f'8 r2 r8 | | %{ bar 696: %} R1 | | %{ bar 697: %} c'8 e'8 g'8 r2 r8 | | %{ bar 698: %} R1 | | %{ bar 699: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 700: %} R1 | | %{ bar 701: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 702: %} R1 | | %{ bar 703: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 704: %} R1 | | %{ bar 705: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 706: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 707: %} R1 | | %{ bar 708: %} c'8 e'8 a'8 r2 r8 | | %{ bar 709: %} R1 | | %{ bar 710: %} c'8 e'8 f'8 r2 r8 | | %{ bar 711: %} R1 | | %{ bar 712: %} c'8 e'8 g'8 r2 r8 | | %{ bar 713: %} R1 | | %{ bar 714: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 715: %} R1 | | %{ bar 716: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 717: %} R1 | | %{ bar 718: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 719: %} R1 | | %{ bar 720: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 721: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 722: %} R1 | | %{ bar 723: %} c'8 e'8 a'8 r2 r8 | | %{ bar 724: %} R1 | | %{ bar 725: %} c'8 e'8 f'8 r2 r8 | | %{ bar 726: %} R1 | | %{ bar 727: %} c'8 e'8 g'8 r2 r8 | | %{ bar 728: %} R1 | | %{ bar 729: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 730: %} R1 | | %{ bar 731: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 732: %} R1 | | %{ bar 733: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 734: %} R1 | | %{ bar 735: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 736: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 737: %} R1 | | %{ bar 738: %} c'8 e'8 a'8 r2 r8 | | %{ bar 739: %} R1 | | %{ bar 740: %} c'8 e'8 f'8 r2 r8 | | %{ bar 741: %} R1 | | %{ bar 742: %} c'8 e'8 g'8 r2 r8 | | %{ bar 743: %} R1 | | %{ bar 744: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 745: %} R1 | | %{ bar 746: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 747: %} R1 | | %{ bar 748: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 749: %} R1 | | %{ bar 750: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 751: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 752: %} R1 | | %{ bar 753: %} c'8 e'8 a'8 r2 r8 | | %{ bar 754: %} R1 | | %{ bar 755: %} c'8 e'8 f'8 r2 r8 | | %{ bar 756: %} R1 | | %{ bar 757: %} c'8 e'8 g'8 r2 r8 | | %{ bar 758: %} R1 | | %{ bar 759: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 760: %} R1 | | %{ bar 761: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 762: %} R1 | | %{ bar 763: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 764: %} R1 | | %{ bar 765: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 766: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 767: %} R1 | | %{ bar 768: %} c'8 e'8 a'8 r2 r8 | | %{ bar 769: %} R1 | | %{ bar 770: %} c'8 e'8 f'8 r2 r8 | | %{ bar 771: %} R1 | | %{ bar 772: %} c'8 e'8 g'8 r2 r8 | | %{ bar 773: %} R1 | | %{ bar 774: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 775: %} R1 | | %{ bar 776: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 777: %} R1 | | %{ bar 778: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 779: %} R1 | | %{ bar 780: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 781: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 782: %} R1 | | %{ bar 783: %} c'8 e'8 a'8 r2 r8 | | %{ bar 784: %} R1 | | %{ bar 785: %} c'8 e'8 f'8 r2 r8 | | %{ bar 786: %} R1 | | %{ bar 787: %} c'8 e'8 g'8 r2 r8 | | %{ bar 788: %} R1 | | %{ bar 789: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 790: %} R1 | | %{ bar 791: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 792: %} R1 | | %{ bar 793: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 794: %} R1 | | %{ bar 795: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 796: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 797: %} R1 | | %{ bar 798: %} c'8 e'8 a'8 r2 r8 | | %{ bar 799: %} R1 | | %{ bar 800: %} c'8 e'8 f'8 r2 r8 | | %{ bar 801: %} R1 | | %{ bar 802: %} c'8 e'8 g'8 r2 r8 | | %{ bar 803: %} R1 | | %{ bar 804: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 805: %} R1 | | %{ bar 806: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 807: %} R1 | | %{ bar 808: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 809: %} R1 | | %{ bar 810: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 811: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 812: %} R1 | | %{ bar 813: %} c'8 e'8 a'8 r2 r8 | | %{ bar 814: %} R1 | | %{ bar 815: %} c'8 e'8 f'8 r2 r8 | | %{ bar 816: %} R1 | | %{ bar 817: %} c'8 e'8 g'8 r2 r8 | | %{ bar 818: %} R1 | | %{ bar 819: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 820: %} R1 | | %{ bar 821: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 822: %} R1 | | %{ bar 823: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 824: %} R1 | | %{ bar 825: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 826: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 827: %} R1 | | %{ bar 828: %} c'8 e'8 a'8 r2 r8 | | %{ bar 829: %} R1 | | %{ bar 830: %} c'8 e'8 f'8 r2 r8 | | %{ bar 831: %} R1 | | %{ bar 832: %} c'8 e'8 g'8 r2 r8 | | %{ bar 833: %} R1 | | %{ bar 834: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 835: %} R1 | | %{ bar 836: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 837: %} R1 | | %{ bar 838: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 839: %} R1 | | %{ bar 840: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 841: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 842: %} R1 | | %{ bar 843: %} c'8 e'8 a'8 r2 r8 | | %{ bar 844: %} R1 | | %{ bar 845: %} c'8 e'8 f'8 r2 r8 | | %{ bar 846: %} R1 | | %{ bar 847: %} c'8 e'8 g'8 r2 r8 | | %{ bar 848: %} R1 | | %{ bar 849: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 850: %} R1 | | %{ bar 851: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 852: %} R1 | | %{ bar 853: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 854: %} R1 | | %{ bar 855: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 856: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 857: %} R1 | | %{ bar 858: %} c'8 e'8 a'8 r2 r8 | | %{ bar 859: %} R1 | | %{ bar 860: %} c'8 e'8 f'8 r2 r8 | | %{ bar 861: %} R1 | | %{ bar 862: %} c'8 e'8 g'8 r2 r8 | | %{ bar 863: %} R1 | | %{ bar 864: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 865: %} R1 | | %{ bar 866: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 867: %} R1 | | %{ bar 868: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 869: %} R1 | | %{ bar 870: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 871: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 872: %} R1 | | %{ bar 873: %} c'8 e'8 a'8 r2 r8 | | %{ bar 874: %} R1 | | %{ bar 875: %} c'8 e'8 f'8 r2 r8 | | %{ bar 876: %} R1 | | %{ bar 877: %} c'8 e'8 g'8 r2 r8 | | %{ bar 878: %} R1 | | %{ bar 879: %} c'8. d'8  ~ d'4 r4 r8. | | %{ bar 880: %} R1 | | %{ bar 881: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 882: %} R1 | | %{ bar 883: %} c'8  ~ c'4 d'8  ~ d'4 r4 | | %{ bar 884: %} R1 | | %{ bar 885: %} c'8  ~ c'4 d'8  ~ d'4 r4 | %{ bar 886: %} b'4 d'8  ~ d'4 r4 r8 | | %{ bar 887: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="再唱洪湖水"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
