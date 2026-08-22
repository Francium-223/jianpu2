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
1' 4 4 0
0 q3 - 0 q0 | 0 0 0 0 |
6 q2 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 7 - q0 5 - 6 - | 0 0 0 0 |
q3 - 0 0 q0 | - 0 0 0 | 0 0 0 0 |
1 1' - 2' - 1 0 - | - 0 0 0 | 0 0 0 0 |
4 5 6 7 | q2 0 0 0 q0 | 0 0 0 0 |
1. 0 0 q0
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
      \note-mod "1" c''4^.  \note-mod "4" f'4  \note-mod "4" f'4  \note-mod "0" r4 | %{ bar 2: %}
 \note-mod "0" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "6" a'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 7: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 8: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 9: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 10: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 12: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 13: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 14: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 16: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 19: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 20: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 21: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 22: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 23: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 24: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 25: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 26: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 27: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 28: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 29: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 31: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 32: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 33: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 34: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 35: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 36: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 37: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 38: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 39: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 40: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 41: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 42: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 43: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 44: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 45: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 46: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 47: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 48: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 49: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 50: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 51: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 52: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 53: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 54: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 55: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 56: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 57: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 58: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 59: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 60: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 61: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 62: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 63: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 64: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 65: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 66: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 67: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 68: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 69: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 70: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 71: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 72: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 73: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 74: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 75: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 76: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 77: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 78: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 79: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 80: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 81: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 82: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 83: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 84: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 85: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 86: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 87: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 88: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 89: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 90: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 91: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 92: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 93: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 94: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 95: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 96: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 97: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 98: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 99: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 100: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 101: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 102: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 103: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 104: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 105: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 106: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 107: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 108: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 109: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 111: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 112: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 113: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 114: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 115: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 116: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 117: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 118: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 119: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 120: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 121: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 122: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 123: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 124: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 125: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 126: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 127: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 128: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 129: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 130: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 131: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 132: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 133: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 134: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 135: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 136: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 137: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 138: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 139: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 140: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 141: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 142: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 143: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 144: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 145: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 146: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 147: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 148: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 149: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 150: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 151: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 152: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 153: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 154: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 155: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 156: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 157: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 158: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 159: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 160: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 161: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 162: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 163: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 164: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 165: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 166: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 167: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 168: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 169: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 170: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 171: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 172: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 173: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 174: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 175: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 176: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 177: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 178: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 179: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 180: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 181: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 182: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 183: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 184: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 185: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 186: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 187: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 188: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 189: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 190: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 191: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 192: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 193: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 194: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 195: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 196: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 197: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 198: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 199: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 200: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 201: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 202: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 203: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 204: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 205: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 206: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 207: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 208: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 209: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 210: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 211: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 212: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 213: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 214: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 215: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 216: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 217: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 218: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 219: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 220: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 221: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 222: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 223: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 224: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 225: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 226: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 227: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 228: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 229: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 230: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 231: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 232: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 233: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 234: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 235: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 236: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 237: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 238: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 239: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 240: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 241: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 242: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 243: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 244: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 245: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 246: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 247: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 248: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 249: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 250: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 251: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 252: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 253: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 254: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 255: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 256: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 257: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 258: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 259: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 260: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 261: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 262: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 263: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 264: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 265: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 266: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 267: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 268: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 269: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 270: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 271: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 272: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 273: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 274: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 275: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 276: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 277: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 278: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 279: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 280: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 281: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 282: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 283: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 284: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 285: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 286: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 287: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 288: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 289: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 290: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 291: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 292: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 293: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 294: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 295: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 296: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 297: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 298: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 299: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 300: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 301: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 302: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 303: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 304: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 305: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 306: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 307: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 308: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 309: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 310: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 311: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 312: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 313: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 314: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 315: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 316: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 317: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 318: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 319: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 320: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 321: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 322: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 323: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 324: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 325: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 326: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 327: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 328: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 329: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 330: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 331: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 332: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 333: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 334: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 335: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 336: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 337: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 338: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 339: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 340: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 341: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 342: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 343: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 344: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 345: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 346: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 347: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 348: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 349: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 350: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 351: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 352: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 353: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 354: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 355: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 356: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 357: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 358: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 359: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 360: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 361: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 362: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 363: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 364: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 365: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 366: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 367: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 368: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 369: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 370: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 371: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 372: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 373: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 374: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 375: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 376: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 377: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 378: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 379: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 380: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 381: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 382: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 383: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 384: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 385: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 386: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 387: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 388: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 389: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 390: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 391: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 392: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 393: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 394: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 395: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 396: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 397: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 398: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 399: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 400: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 401: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 402: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 403: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 404: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 405: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 406: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 407: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 408: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 409: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 410: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 411: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 412: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 413: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 414: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 415: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 416: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 417: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 418: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 419: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 420: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 421: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 422: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 423: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 424: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 425: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 426: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 427: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 428: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 429: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 430: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 431: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 432: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 433: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 434: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 435: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 436: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 437: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 438: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 439: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 440: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 441: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 442: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 443: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 444: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 445: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 446: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 447: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 448: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 449: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 450: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 451: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 452: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 453: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 454: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 455: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 456: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 457: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 458: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 459: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 460: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 461: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 462: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 463: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 464: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 465: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 466: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 467: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 468: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 469: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 470: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 471: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 472: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 473: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 474: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 475: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 476: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 477: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 478: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 479: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 480: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 481: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 482: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 483: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 484: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 485: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 486: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 487: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 488: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 489: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 490: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 491: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 492: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 493: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 494: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 495: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 496: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 497: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 498: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 499: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 500: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 501: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 502: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 503: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 504: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 505: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 506: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 507: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 508: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 509: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 510: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 511: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 512: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 513: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 514: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 515: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 516: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 517: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 518: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 519: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 520: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 521: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 522: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 523: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 524: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 525: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 526: %}
 \note-mod "1" c'4.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 527: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | | %{ bar 528: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 529: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 530: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 531: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 532: %}
 \note-mod "1" c'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | %{ bar 533: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 | | %{ bar 534: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 535: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 536: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "7" b'4 | | %{ bar 537: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 538: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 539: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\bar "|." } }
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
    \new Staff { \new Voice="X" { c''4 f'4 f'4 r4 | %{ bar 2: %} r4 e'8  ~ e'4 r4 r8 | | %{ bar 3: %} R1 | | %{ bar 4: %} a'4 d'8 r2 r8 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'4. b'2 r8 | %{ bar 7: %} g'2 a'2 | | %{ bar 8: %} R1 | | %{ bar 9: %} e'8  ~ e'4 r2 r8 | | %{ bar 10: %} R1 | | %{ bar 11: %} R1 | | %{ bar 12: %} c'4 c''2 d''4  ~ | %{ bar 13: %} d''4 c'4 r2 | | %{ bar 14: %} R1 | | %{ bar 15: %} R1 | | %{ bar 16: %} f'4 g'4 a'4 b'4 | | %{ bar 17: %} d'8 r2. r8 | | %{ bar 18: %} R1 | | %{ bar 19: %} c'4. b'2 r8 | %{ bar 20: %} g'2 a'2 | | %{ bar 21: %} R1 | | %{ bar 22: %} e'8  ~ e'4 r2 r8 | | %{ bar 23: %} R1 | | %{ bar 24: %} R1 | | %{ bar 25: %} c'4 c''2 d''4  ~ | %{ bar 26: %} d''4 c'4 r2 | | %{ bar 27: %} R1 | | %{ bar 28: %} R1 | | %{ bar 29: %} f'4 g'4 a'4 b'4 | | %{ bar 30: %} d'8 r2. r8 | | %{ bar 31: %} R1 | | %{ bar 32: %} c'4. b'2 r8 | %{ bar 33: %} g'2 a'2 | | %{ bar 34: %} R1 | | %{ bar 35: %} e'8  ~ e'4 r2 r8 | | %{ bar 36: %} R1 | | %{ bar 37: %} R1 | | %{ bar 38: %} c'4 c''2 d''4  ~ | %{ bar 39: %} d''4 c'4 r2 | | %{ bar 40: %} R1 | | %{ bar 41: %} R1 | | %{ bar 42: %} f'4 g'4 a'4 b'4 | | %{ bar 43: %} d'8 r2. r8 | | %{ bar 44: %} R1 | | %{ bar 45: %} c'4. b'2 r8 | %{ bar 46: %} g'2 a'2 | | %{ bar 47: %} R1 | | %{ bar 48: %} e'8  ~ e'4 r2 r8 | | %{ bar 49: %} R1 | | %{ bar 50: %} R1 | | %{ bar 51: %} c'4 c''2 d''4  ~ | %{ bar 52: %} d''4 c'4 r2 | | %{ bar 53: %} R1 | | %{ bar 54: %} R1 | | %{ bar 55: %} f'4 g'4 a'4 b'4 | | %{ bar 56: %} d'8 r2. r8 | | %{ bar 57: %} R1 | | %{ bar 58: %} c'4. b'2 r8 | %{ bar 59: %} g'2 a'2 | | %{ bar 60: %} R1 | | %{ bar 61: %} e'8  ~ e'4 r2 r8 | | %{ bar 62: %} R1 | | %{ bar 63: %} R1 | | %{ bar 64: %} c'4 c''2 d''4  ~ | %{ bar 65: %} d''4 c'4 r2 | | %{ bar 66: %} R1 | | %{ bar 67: %} R1 | | %{ bar 68: %} f'4 g'4 a'4 b'4 | | %{ bar 69: %} d'8 r2. r8 | | %{ bar 70: %} R1 | | %{ bar 71: %} c'4. b'2 r8 | %{ bar 72: %} g'2 a'2 | | %{ bar 73: %} R1 | | %{ bar 74: %} e'8  ~ e'4 r2 r8 | | %{ bar 75: %} R1 | | %{ bar 76: %} R1 | | %{ bar 77: %} c'4 c''2 d''4  ~ | %{ bar 78: %} d''4 c'4 r2 | | %{ bar 79: %} R1 | | %{ bar 80: %} R1 | | %{ bar 81: %} f'4 g'4 a'4 b'4 | | %{ bar 82: %} d'8 r2. r8 | | %{ bar 83: %} R1 | | %{ bar 84: %} c'4. b'2 r8 | %{ bar 85: %} g'2 a'2 | | %{ bar 86: %} R1 | | %{ bar 87: %} e'8  ~ e'4 r2 r8 | | %{ bar 88: %} R1 | | %{ bar 89: %} R1 | | %{ bar 90: %} c'4 c''2 d''4  ~ | %{ bar 91: %} d''4 c'4 r2 | | %{ bar 92: %} R1 | | %{ bar 93: %} R1 | | %{ bar 94: %} f'4 g'4 a'4 b'4 | | %{ bar 95: %} d'8 r2. r8 | | %{ bar 96: %} R1 | | %{ bar 97: %} c'4. b'2 r8 | %{ bar 98: %} g'2 a'2 | | %{ bar 99: %} R1 | | %{ bar 100: %} e'8  ~ e'4 r2 r8 | | %{ bar 101: %} R1 | | %{ bar 102: %} R1 | | %{ bar 103: %} c'4 c''2 d''4  ~ | %{ bar 104: %} d''4 c'4 r2 | | %{ bar 105: %} R1 | | %{ bar 106: %} R1 | | %{ bar 107: %} f'4 g'4 a'4 b'4 | | %{ bar 108: %} d'8 r2. r8 | | %{ bar 109: %} R1 | | %{ bar 110: %} c'4. b'2 r8 | %{ bar 111: %} g'2 a'2 | | %{ bar 112: %} R1 | | %{ bar 113: %} e'8  ~ e'4 r2 r8 | | %{ bar 114: %} R1 | | %{ bar 115: %} R1 | | %{ bar 116: %} c'4 c''2 d''4  ~ | %{ bar 117: %} d''4 c'4 r2 | | %{ bar 118: %} R1 | | %{ bar 119: %} R1 | | %{ bar 120: %} f'4 g'4 a'4 b'4 | | %{ bar 121: %} d'8 r2. r8 | | %{ bar 122: %} R1 | | %{ bar 123: %} c'4. b'2 r8 | %{ bar 124: %} g'2 a'2 | | %{ bar 125: %} R1 | | %{ bar 126: %} e'8  ~ e'4 r2 r8 | | %{ bar 127: %} R1 | | %{ bar 128: %} R1 | | %{ bar 129: %} c'4 c''2 d''4  ~ | %{ bar 130: %} d''4 c'4 r2 | | %{ bar 131: %} R1 | | %{ bar 132: %} R1 | | %{ bar 133: %} f'4 g'4 a'4 b'4 | | %{ bar 134: %} d'8 r2. r8 | | %{ bar 135: %} R1 | | %{ bar 136: %} c'4. b'2 r8 | %{ bar 137: %} g'2 a'2 | | %{ bar 138: %} R1 | | %{ bar 139: %} e'8  ~ e'4 r2 r8 | | %{ bar 140: %} R1 | | %{ bar 141: %} R1 | | %{ bar 142: %} c'4 c''2 d''4  ~ | %{ bar 143: %} d''4 c'4 r2 | | %{ bar 144: %} R1 | | %{ bar 145: %} R1 | | %{ bar 146: %} f'4 g'4 a'4 b'4 | | %{ bar 147: %} d'8 r2. r8 | | %{ bar 148: %} R1 | | %{ bar 149: %} c'4. b'2 r8 | %{ bar 150: %} g'2 a'2 | | %{ bar 151: %} R1 | | %{ bar 152: %} e'8  ~ e'4 r2 r8 | | %{ bar 153: %} R1 | | %{ bar 154: %} R1 | | %{ bar 155: %} c'4 c''2 d''4  ~ | %{ bar 156: %} d''4 c'4 r2 | | %{ bar 157: %} R1 | | %{ bar 158: %} R1 | | %{ bar 159: %} f'4 g'4 a'4 b'4 | | %{ bar 160: %} d'8 r2. r8 | | %{ bar 161: %} R1 | | %{ bar 162: %} c'4. b'2 r8 | %{ bar 163: %} g'2 a'2 | | %{ bar 164: %} R1 | | %{ bar 165: %} e'8  ~ e'4 r2 r8 | | %{ bar 166: %} R1 | | %{ bar 167: %} R1 | | %{ bar 168: %} c'4 c''2 d''4  ~ | %{ bar 169: %} d''4 c'4 r2 | | %{ bar 170: %} R1 | | %{ bar 171: %} R1 | | %{ bar 172: %} f'4 g'4 a'4 b'4 | | %{ bar 173: %} d'8 r2. r8 | | %{ bar 174: %} R1 | | %{ bar 175: %} c'4. b'2 r8 | %{ bar 176: %} g'2 a'2 | | %{ bar 177: %} R1 | | %{ bar 178: %} e'8  ~ e'4 r2 r8 | | %{ bar 179: %} R1 | | %{ bar 180: %} R1 | | %{ bar 181: %} c'4 c''2 d''4  ~ | %{ bar 182: %} d''4 c'4 r2 | | %{ bar 183: %} R1 | | %{ bar 184: %} R1 | | %{ bar 185: %} f'4 g'4 a'4 b'4 | | %{ bar 186: %} d'8 r2. r8 | | %{ bar 187: %} R1 | | %{ bar 188: %} c'4. b'2 r8 | %{ bar 189: %} g'2 a'2 | | %{ bar 190: %} R1 | | %{ bar 191: %} e'8  ~ e'4 r2 r8 | | %{ bar 192: %} R1 | | %{ bar 193: %} R1 | | %{ bar 194: %} c'4 c''2 d''4  ~ | %{ bar 195: %} d''4 c'4 r2 | | %{ bar 196: %} R1 | | %{ bar 197: %} R1 | | %{ bar 198: %} f'4 g'4 a'4 b'4 | | %{ bar 199: %} d'8 r2. r8 | | %{ bar 200: %} R1 | | %{ bar 201: %} c'4. b'2 r8 | %{ bar 202: %} g'2 a'2 | | %{ bar 203: %} R1 | | %{ bar 204: %} e'8  ~ e'4 r2 r8 | | %{ bar 205: %} R1 | | %{ bar 206: %} R1 | | %{ bar 207: %} c'4 c''2 d''4  ~ | %{ bar 208: %} d''4 c'4 r2 | | %{ bar 209: %} R1 | | %{ bar 210: %} R1 | | %{ bar 211: %} f'4 g'4 a'4 b'4 | | %{ bar 212: %} d'8 r2. r8 | | %{ bar 213: %} R1 | | %{ bar 214: %} c'4. b'2 r8 | %{ bar 215: %} g'2 a'2 | | %{ bar 216: %} R1 | | %{ bar 217: %} e'8  ~ e'4 r2 r8 | | %{ bar 218: %} R1 | | %{ bar 219: %} R1 | | %{ bar 220: %} c'4 c''2 d''4  ~ | %{ bar 221: %} d''4 c'4 r2 | | %{ bar 222: %} R1 | | %{ bar 223: %} R1 | | %{ bar 224: %} f'4 g'4 a'4 b'4 | | %{ bar 225: %} d'8 r2. r8 | | %{ bar 226: %} R1 | | %{ bar 227: %} c'4. b'2 r8 | %{ bar 228: %} g'2 a'2 | | %{ bar 229: %} R1 | | %{ bar 230: %} e'8  ~ e'4 r2 r8 | | %{ bar 231: %} R1 | | %{ bar 232: %} R1 | | %{ bar 233: %} c'4 c''2 d''4  ~ | %{ bar 234: %} d''4 c'4 r2 | | %{ bar 235: %} R1 | | %{ bar 236: %} R1 | | %{ bar 237: %} f'4 g'4 a'4 b'4 | | %{ bar 238: %} d'8 r2. r8 | | %{ bar 239: %} R1 | | %{ bar 240: %} c'4. b'2 r8 | %{ bar 241: %} g'2 a'2 | | %{ bar 242: %} R1 | | %{ bar 243: %} e'8  ~ e'4 r2 r8 | | %{ bar 244: %} R1 | | %{ bar 245: %} R1 | | %{ bar 246: %} c'4 c''2 d''4  ~ | %{ bar 247: %} d''4 c'4 r2 | | %{ bar 248: %} R1 | | %{ bar 249: %} R1 | | %{ bar 250: %} f'4 g'4 a'4 b'4 | | %{ bar 251: %} d'8 r2. r8 | | %{ bar 252: %} R1 | | %{ bar 253: %} c'4. b'2 r8 | %{ bar 254: %} g'2 a'2 | | %{ bar 255: %} R1 | | %{ bar 256: %} e'8  ~ e'4 r2 r8 | | %{ bar 257: %} R1 | | %{ bar 258: %} R1 | | %{ bar 259: %} c'4 c''2 d''4  ~ | %{ bar 260: %} d''4 c'4 r2 | | %{ bar 261: %} R1 | | %{ bar 262: %} R1 | | %{ bar 263: %} f'4 g'4 a'4 b'4 | | %{ bar 264: %} d'8 r2. r8 | | %{ bar 265: %} R1 | | %{ bar 266: %} c'4. b'2 r8 | %{ bar 267: %} g'2 a'2 | | %{ bar 268: %} R1 | | %{ bar 269: %} e'8  ~ e'4 r2 r8 | | %{ bar 270: %} R1 | | %{ bar 271: %} R1 | | %{ bar 272: %} c'4 c''2 d''4  ~ | %{ bar 273: %} d''4 c'4 r2 | | %{ bar 274: %} R1 | | %{ bar 275: %} R1 | | %{ bar 276: %} f'4 g'4 a'4 b'4 | | %{ bar 277: %} d'8 r2. r8 | | %{ bar 278: %} R1 | | %{ bar 279: %} c'4. b'2 r8 | %{ bar 280: %} g'2 a'2 | | %{ bar 281: %} R1 | | %{ bar 282: %} e'8  ~ e'4 r2 r8 | | %{ bar 283: %} R1 | | %{ bar 284: %} R1 | | %{ bar 285: %} c'4 c''2 d''4  ~ | %{ bar 286: %} d''4 c'4 r2 | | %{ bar 287: %} R1 | | %{ bar 288: %} R1 | | %{ bar 289: %} f'4 g'4 a'4 b'4 | | %{ bar 290: %} d'8 r2. r8 | | %{ bar 291: %} R1 | | %{ bar 292: %} c'4. b'2 r8 | %{ bar 293: %} g'2 a'2 | | %{ bar 294: %} R1 | | %{ bar 295: %} e'8  ~ e'4 r2 r8 | | %{ bar 296: %} R1 | | %{ bar 297: %} R1 | | %{ bar 298: %} c'4 c''2 d''4  ~ | %{ bar 299: %} d''4 c'4 r2 | | %{ bar 300: %} R1 | | %{ bar 301: %} R1 | | %{ bar 302: %} f'4 g'4 a'4 b'4 | | %{ bar 303: %} d'8 r2. r8 | | %{ bar 304: %} R1 | | %{ bar 305: %} c'4. b'2 r8 | %{ bar 306: %} g'2 a'2 | | %{ bar 307: %} R1 | | %{ bar 308: %} e'8  ~ e'4 r2 r8 | | %{ bar 309: %} R1 | | %{ bar 310: %} R1 | | %{ bar 311: %} c'4 c''2 d''4  ~ | %{ bar 312: %} d''4 c'4 r2 | | %{ bar 313: %} R1 | | %{ bar 314: %} R1 | | %{ bar 315: %} f'4 g'4 a'4 b'4 | | %{ bar 316: %} d'8 r2. r8 | | %{ bar 317: %} R1 | | %{ bar 318: %} c'4. b'2 r8 | %{ bar 319: %} g'2 a'2 | | %{ bar 320: %} R1 | | %{ bar 321: %} e'8  ~ e'4 r2 r8 | | %{ bar 322: %} R1 | | %{ bar 323: %} R1 | | %{ bar 324: %} c'4 c''2 d''4  ~ | %{ bar 325: %} d''4 c'4 r2 | | %{ bar 326: %} R1 | | %{ bar 327: %} R1 | | %{ bar 328: %} f'4 g'4 a'4 b'4 | | %{ bar 329: %} d'8 r2. r8 | | %{ bar 330: %} R1 | | %{ bar 331: %} c'4. b'2 r8 | %{ bar 332: %} g'2 a'2 | | %{ bar 333: %} R1 | | %{ bar 334: %} e'8  ~ e'4 r2 r8 | | %{ bar 335: %} R1 | | %{ bar 336: %} R1 | | %{ bar 337: %} c'4 c''2 d''4  ~ | %{ bar 338: %} d''4 c'4 r2 | | %{ bar 339: %} R1 | | %{ bar 340: %} R1 | | %{ bar 341: %} f'4 g'4 a'4 b'4 | | %{ bar 342: %} d'8 r2. r8 | | %{ bar 343: %} R1 | | %{ bar 344: %} c'4. b'2 r8 | %{ bar 345: %} g'2 a'2 | | %{ bar 346: %} R1 | | %{ bar 347: %} e'8  ~ e'4 r2 r8 | | %{ bar 348: %} R1 | | %{ bar 349: %} R1 | | %{ bar 350: %} c'4 c''2 d''4  ~ | %{ bar 351: %} d''4 c'4 r2 | | %{ bar 352: %} R1 | | %{ bar 353: %} R1 | | %{ bar 354: %} f'4 g'4 a'4 b'4 | | %{ bar 355: %} d'8 r2. r8 | | %{ bar 356: %} R1 | | %{ bar 357: %} c'4. b'2 r8 | %{ bar 358: %} g'2 a'2 | | %{ bar 359: %} R1 | | %{ bar 360: %} e'8  ~ e'4 r2 r8 | | %{ bar 361: %} R1 | | %{ bar 362: %} R1 | | %{ bar 363: %} c'4 c''2 d''4  ~ | %{ bar 364: %} d''4 c'4 r2 | | %{ bar 365: %} R1 | | %{ bar 366: %} R1 | | %{ bar 367: %} f'4 g'4 a'4 b'4 | | %{ bar 368: %} d'8 r2. r8 | | %{ bar 369: %} R1 | | %{ bar 370: %} c'4. b'2 r8 | %{ bar 371: %} g'2 a'2 | | %{ bar 372: %} R1 | | %{ bar 373: %} e'8  ~ e'4 r2 r8 | | %{ bar 374: %} R1 | | %{ bar 375: %} R1 | | %{ bar 376: %} c'4 c''2 d''4  ~ | %{ bar 377: %} d''4 c'4 r2 | | %{ bar 378: %} R1 | | %{ bar 379: %} R1 | | %{ bar 380: %} f'4 g'4 a'4 b'4 | | %{ bar 381: %} d'8 r2. r8 | | %{ bar 382: %} R1 | | %{ bar 383: %} c'4. b'2 r8 | %{ bar 384: %} g'2 a'2 | | %{ bar 385: %} R1 | | %{ bar 386: %} e'8  ~ e'4 r2 r8 | | %{ bar 387: %} R1 | | %{ bar 388: %} R1 | | %{ bar 389: %} c'4 c''2 d''4  ~ | %{ bar 390: %} d''4 c'4 r2 | | %{ bar 391: %} R1 | | %{ bar 392: %} R1 | | %{ bar 393: %} f'4 g'4 a'4 b'4 | | %{ bar 394: %} d'8 r2. r8 | | %{ bar 395: %} R1 | | %{ bar 396: %} c'4. b'2 r8 | %{ bar 397: %} g'2 a'2 | | %{ bar 398: %} R1 | | %{ bar 399: %} e'8  ~ e'4 r2 r8 | | %{ bar 400: %} R1 | | %{ bar 401: %} R1 | | %{ bar 402: %} c'4 c''2 d''4  ~ | %{ bar 403: %} d''4 c'4 r2 | | %{ bar 404: %} R1 | | %{ bar 405: %} R1 | | %{ bar 406: %} f'4 g'4 a'4 b'4 | | %{ bar 407: %} d'8 r2. r8 | | %{ bar 408: %} R1 | | %{ bar 409: %} c'4. b'2 r8 | %{ bar 410: %} g'2 a'2 | | %{ bar 411: %} R1 | | %{ bar 412: %} e'8  ~ e'4 r2 r8 | | %{ bar 413: %} R1 | | %{ bar 414: %} R1 | | %{ bar 415: %} c'4 c''2 d''4  ~ | %{ bar 416: %} d''4 c'4 r2 | | %{ bar 417: %} R1 | | %{ bar 418: %} R1 | | %{ bar 419: %} f'4 g'4 a'4 b'4 | | %{ bar 420: %} d'8 r2. r8 | | %{ bar 421: %} R1 | | %{ bar 422: %} c'4. b'2 r8 | %{ bar 423: %} g'2 a'2 | | %{ bar 424: %} R1 | | %{ bar 425: %} e'8  ~ e'4 r2 r8 | | %{ bar 426: %} R1 | | %{ bar 427: %} R1 | | %{ bar 428: %} c'4 c''2 d''4  ~ | %{ bar 429: %} d''4 c'4 r2 | | %{ bar 430: %} R1 | | %{ bar 431: %} R1 | | %{ bar 432: %} f'4 g'4 a'4 b'4 | | %{ bar 433: %} d'8 r2. r8 | | %{ bar 434: %} R1 | | %{ bar 435: %} c'4. b'2 r8 | %{ bar 436: %} g'2 a'2 | | %{ bar 437: %} R1 | | %{ bar 438: %} e'8  ~ e'4 r2 r8 | | %{ bar 439: %} R1 | | %{ bar 440: %} R1 | | %{ bar 441: %} c'4 c''2 d''4  ~ | %{ bar 442: %} d''4 c'4 r2 | | %{ bar 443: %} R1 | | %{ bar 444: %} R1 | | %{ bar 445: %} f'4 g'4 a'4 b'4 | | %{ bar 446: %} d'8 r2. r8 | | %{ bar 447: %} R1 | | %{ bar 448: %} c'4. b'2 r8 | %{ bar 449: %} g'2 a'2 | | %{ bar 450: %} R1 | | %{ bar 451: %} e'8  ~ e'4 r2 r8 | | %{ bar 452: %} R1 | | %{ bar 453: %} R1 | | %{ bar 454: %} c'4 c''2 d''4  ~ | %{ bar 455: %} d''4 c'4 r2 | | %{ bar 456: %} R1 | | %{ bar 457: %} R1 | | %{ bar 458: %} f'4 g'4 a'4 b'4 | | %{ bar 459: %} d'8 r2. r8 | | %{ bar 460: %} R1 | | %{ bar 461: %} c'4. b'2 r8 | %{ bar 462: %} g'2 a'2 | | %{ bar 463: %} R1 | | %{ bar 464: %} e'8  ~ e'4 r2 r8 | | %{ bar 465: %} R1 | | %{ bar 466: %} R1 | | %{ bar 467: %} c'4 c''2 d''4  ~ | %{ bar 468: %} d''4 c'4 r2 | | %{ bar 469: %} R1 | | %{ bar 470: %} R1 | | %{ bar 471: %} f'4 g'4 a'4 b'4 | | %{ bar 472: %} d'8 r2. r8 | | %{ bar 473: %} R1 | | %{ bar 474: %} c'4. b'2 r8 | %{ bar 475: %} g'2 a'2 | | %{ bar 476: %} R1 | | %{ bar 477: %} e'8  ~ e'4 r2 r8 | | %{ bar 478: %} R1 | | %{ bar 479: %} R1 | | %{ bar 480: %} c'4 c''2 d''4  ~ | %{ bar 481: %} d''4 c'4 r2 | | %{ bar 482: %} R1 | | %{ bar 483: %} R1 | | %{ bar 484: %} f'4 g'4 a'4 b'4 | | %{ bar 485: %} d'8 r2. r8 | | %{ bar 486: %} R1 | | %{ bar 487: %} c'4. b'2 r8 | %{ bar 488: %} g'2 a'2 | | %{ bar 489: %} R1 | | %{ bar 490: %} e'8  ~ e'4 r2 r8 | | %{ bar 491: %} R1 | | %{ bar 492: %} R1 | | %{ bar 493: %} c'4 c''2 d''4  ~ | %{ bar 494: %} d''4 c'4 r2 | | %{ bar 495: %} R1 | | %{ bar 496: %} R1 | | %{ bar 497: %} f'4 g'4 a'4 b'4 | | %{ bar 498: %} d'8 r2. r8 | | %{ bar 499: %} R1 | | %{ bar 500: %} c'4. b'2 r8 | %{ bar 501: %} g'2 a'2 | | %{ bar 502: %} R1 | | %{ bar 503: %} e'8  ~ e'4 r2 r8 | | %{ bar 504: %} R1 | | %{ bar 505: %} R1 | | %{ bar 506: %} c'4 c''2 d''4  ~ | %{ bar 507: %} d''4 c'4 r2 | | %{ bar 508: %} R1 | | %{ bar 509: %} R1 | | %{ bar 510: %} f'4 g'4 a'4 b'4 | | %{ bar 511: %} d'8 r2. r8 | | %{ bar 512: %} R1 | | %{ bar 513: %} c'4. b'2 r8 | %{ bar 514: %} g'2 a'2 | | %{ bar 515: %} R1 | | %{ bar 516: %} e'8  ~ e'4 r2 r8 | | %{ bar 517: %} R1 | | %{ bar 518: %} R1 | | %{ bar 519: %} c'4 c''2 d''4  ~ | %{ bar 520: %} d''4 c'4 r2 | | %{ bar 521: %} R1 | | %{ bar 522: %} R1 | | %{ bar 523: %} f'4 g'4 a'4 b'4 | | %{ bar 524: %} d'8 r2. r8 | | %{ bar 525: %} R1 | | %{ bar 526: %} c'4. b'2 r8 | %{ bar 527: %} g'2 a'2 | | %{ bar 528: %} R1 | | %{ bar 529: %} e'8  ~ e'4 r2 r8 | | %{ bar 530: %} R1 | | %{ bar 531: %} R1 | | %{ bar 532: %} c'4 c''2 d''4  ~ | %{ bar 533: %} d''4 c'4 r2 | | %{ bar 534: %} R1 | | %{ bar 535: %} R1 | | %{ bar 536: %} f'4 g'4 a'4 b'4 | | %{ bar 537: %} d'8 r2. r8 | | %{ bar 538: %} R1 | | %{ bar 539: %} c'4. r2 r8 } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
