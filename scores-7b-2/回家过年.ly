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
5 - 6 0 | q3 q2 0 0 0 | 1' - 1' 0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | q1 6. q1 7 q0 | 0 0 0 0 |
5 - 6 0 | q3 1' - 1' q0 | 0 0 0 0 |
q1. 0 0 0 s0 | q7 q1' 0 0 0 | q2' q1 0 0 0 | 0 0 0 0 |
q1 1. q1 2 q0 | 0 0 0 0 |
0 0 0 0 | q1 3. 1' 0 | q1 4. q1 5 q0 | 0 0 0 0 |
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
    \override Stem.length-fraction = #0.5
    \override Beam.beam-thickness = #0.1
    \override Beam.length-fraction = #0.5
    \override Beam.after-line-breaking = #flip-beams
    \override Voice.Rest.style = #'neomensural % this size tends to line up better (we'll override the appearance anyway)
    \override Accidental.font-size = #-4
    \override TupletBracket.bracket-visibility = ##t

    \override Staff.TimeSignature.style = #'numbered
    \override Staff.Stem.transparent = ##t
     \time 4/4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 3: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 12: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 16: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 19: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 20: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 21: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 22: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 23: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 24: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 25: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 26: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 27: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 28: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 29: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 30: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 31: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 32: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 33: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 34: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 35: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 36: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 37: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 38: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 39: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 40: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 41: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 42: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 43: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 44: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 45: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 46: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 47: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 48: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 49: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 50: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 51: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 52: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 53: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 54: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 55: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 56: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 57: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 58: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 59: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 60: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 61: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 62: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 63: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 64: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 65: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 66: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 67: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 68: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 69: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 70: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 71: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 72: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 73: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 74: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 75: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 76: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 77: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 78: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 79: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 80: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 81: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 82: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 83: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 84: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 85: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 86: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 87: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 88: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 89: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 90: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 91: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 92: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 93: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 94: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 95: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 96: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 97: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 98: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 99: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 100: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 101: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 102: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 103: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 104: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 105: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 106: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 107: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 108: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 109: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 111: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 112: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 113: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 114: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 115: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 116: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 117: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 118: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 119: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 120: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 121: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 122: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 123: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 124: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 125: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 126: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 127: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 128: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 129: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 130: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 131: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 132: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 133: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 134: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 135: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 136: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 137: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 138: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 139: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 140: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 141: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 142: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 143: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 144: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 145: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 146: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 147: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 148: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 149: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 150: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 151: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 152: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 153: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 154: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 155: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 156: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 157: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 158: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 159: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 160: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 161: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 162: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 163: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 164: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 165: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 166: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 167: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 168: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 169: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 170: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 171: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 172: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 173: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 174: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 175: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 176: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 177: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 178: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 179: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 180: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 181: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 182: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 183: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 184: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 185: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 186: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 187: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 188: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 189: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 190: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 191: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 192: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 193: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 194: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 195: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 196: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 197: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 198: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 199: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 200: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 201: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 202: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 203: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 204: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 205: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 206: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 207: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 208: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 209: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 210: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 211: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 212: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 213: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 214: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 215: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 216: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 217: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 218: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 219: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 220: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 221: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 222: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 223: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 224: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 225: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 226: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 227: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 228: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 229: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 230: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 231: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 232: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 233: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 234: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 235: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 236: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 237: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 238: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 239: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 240: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 241: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 242: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 243: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 244: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 245: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 246: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 247: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 248: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 249: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 250: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 251: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 252: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 253: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 254: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 255: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 256: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 257: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 258: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 259: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 260: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 261: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 262: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 263: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 264: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 265: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 266: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 267: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 268: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 269: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 270: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 271: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 272: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 273: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 274: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 275: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 276: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 277: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 278: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 279: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 280: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 281: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 282: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 283: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 284: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 285: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 286: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 287: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 288: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 289: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 290: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 291: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 292: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 293: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 294: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 295: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 296: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 297: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 298: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 299: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 300: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 301: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 302: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 303: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 304: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 305: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 306: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 307: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 308: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 309: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 310: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 311: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 312: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 313: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 314: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 315: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 316: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 317: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 318: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 319: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 320: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 321: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 322: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 323: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 324: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 325: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 326: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 327: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 328: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 329: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 330: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 331: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 332: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 333: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 334: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 335: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 336: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 337: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 338: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 339: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 340: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 341: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 342: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 343: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 344: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 345: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 346: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 347: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 348: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 349: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 350: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 351: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 352: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 353: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 354: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 355: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 356: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 357: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 358: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 359: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 360: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 361: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 362: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 363: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 364: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 365: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 366: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 367: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 368: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 369: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 370: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 371: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 372: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 373: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 374: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 375: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 376: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 377: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 378: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 379: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 380: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 381: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 382: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 383: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 384: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 385: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 386: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 387: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 388: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 389: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 390: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 391: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 392: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 393: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 394: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 395: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 396: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 397: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 398: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 399: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 400: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 401: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 402: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 403: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 404: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 405: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 406: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 407: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 408: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 409: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 410: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 411: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 412: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 413: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 414: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 415: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 416: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 417: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 418: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 419: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 420: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 421: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 422: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 423: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 424: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 425: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 426: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 427: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 428: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 429: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 430: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 431: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 432: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 433: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 434: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 435: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 436: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 437: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 438: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 439: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 440: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 441: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 442: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 443: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 444: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 445: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 446: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 447: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 448: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 449: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 450: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 451: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 452: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 453: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 454: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 455: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 456: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 457: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 458: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 459: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 460: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 461: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 462: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 463: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 464: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 465: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 466: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 467: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 468: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 469: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 470: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 471: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 472: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 473: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 474: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 475: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 476: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 477: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 478: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 479: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 480: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 481: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 482: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 483: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 484: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 485: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 486: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 487: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 488: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 489: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 490: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 491: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 492: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 493: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 494: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 495: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 496: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 497: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 498: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 499: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 500: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 501: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 502: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 503: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 504: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 505: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 506: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 507: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 508: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 509: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 510: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 511: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 512: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 513: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 514: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 515: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 516: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 517: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 518: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 519: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 520: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 521: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 522: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 523: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 524: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 525: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 526: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 527: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 528: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 529: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 530: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 531: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 532: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 533: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 534: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 535: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 536: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 537: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 538: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 539: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 540: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 541: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 542: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 543: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 544: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 545: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 546: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 547: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 548: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 549: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 550: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 551: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 552: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 553: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 554: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 555: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 556: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 557: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 558: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 559: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 560: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 561: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 562: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 563: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 564: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 565: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 566: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 567: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 568: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 569: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 570: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 571: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 572: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 573: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 574: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 575: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 576: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 577: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 578: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 579: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 580: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 581: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 582: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 583: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 584: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 585: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 586: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 587: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 588: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 589: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 590: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 591: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 592: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 593: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 594: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 595: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 596: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 597: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 598: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 599: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 600: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 601: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 602: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 603: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 604: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 605: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 606: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 607: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 608: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 609: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 610: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 611: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 612: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 613: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 614: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 615: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 616: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 617: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 618: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 619: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 620: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 621: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 622: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 623: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 624: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 625: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 626: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 627: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 628: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 629: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 630: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 631: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 632: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 633: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 634: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 635: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 636: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 637: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 638: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 639: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 640: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 641: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 642: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 643: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 644: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 645: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 646: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 647: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 648: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 649: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 650: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 651: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 652: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 653: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 654: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 655: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 656: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 657: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 658: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 659: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 660: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 661: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 662: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 663: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 664: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 665: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 666: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 667: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 668: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 669: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 670: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 671: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 672: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 673: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 674: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 675: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 676: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 677: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 678: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 679: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 680: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 681: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 682: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 683: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 684: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 685: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 686: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 687: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 688: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 689: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 690: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 691: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 692: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 693: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 694: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 695: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 696: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 697: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 698: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 699: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 700: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 701: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 702: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 703: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 704: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 705: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 706: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 707: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 708: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 709: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 710: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 711: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 712: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 713: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 714: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 715: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 716: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 717: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 718: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 719: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 720: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 721: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 722: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 723: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 724: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 725: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 726: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 727: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 728: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 729: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 730: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 731: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 732: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 733: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 734: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 735: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 736: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 737: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 738: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 739: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 740: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 741: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 742: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 743: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 744: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 745: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 746: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 747: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 748: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 749: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 750: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 751: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 752: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 753: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 754: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 755: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 756: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 757: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 758: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 759: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 760: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 761: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 762: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 763: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 764: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 765: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 766: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 767: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 768: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 769: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 770: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 771: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 772: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 773: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 774: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 775: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 776: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 777: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 778: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 779: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 780: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 781: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 782: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 783: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 784: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 785: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 786: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 787: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 788: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 789: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 790: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 791: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 792: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 793: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 794: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 795: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 796: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 797: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 798: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 799: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 800: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 801: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 802: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 803: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 804: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 805: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 806: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 807: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 808: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 809: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 810: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 811: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 812: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 813: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 814: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 815: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 816: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 817: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 818: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 819: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 820: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 821: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 822: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 823: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 824: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 825: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 826: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 827: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 828: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 829: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 830: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 831: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 832: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 833: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 834: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 835: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 836: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 837: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 838: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 839: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 840: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 841: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 842: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 843: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 844: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 845: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 846: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 847: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 848: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 849: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 850: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 851: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 852: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 853: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 854: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 855: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 856: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 857: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 858: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 859: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 860: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 861: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 862: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 863: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 864: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 865: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 866: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 867: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 868: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 869: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 870: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 871: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 872: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 873: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 874: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 875: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 876: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 877: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 878: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 879: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 880: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 881: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 882: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 883: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 884: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 885: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 886: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 887: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 888: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 889: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 890: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 891: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 892: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 893: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 894: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 895: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 896: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 897: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 898: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 899: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 900: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 901: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 902: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 903: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 904: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 905: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 906: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 907: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 908: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 909: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 910: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 911: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 912: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 913: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 914: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 915: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 916: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 917: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 918: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 919: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 920: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 921: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 922: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 923: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 924: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 925: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 926: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 927: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 928: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 929: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 930: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 931: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 932: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 933: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 934: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 935: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 936: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 937: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 938: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 939: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 940: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 941: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 942: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 943: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 944: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 945: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 946: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 947: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 948: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 949: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 950: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 951: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 952: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 953: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 954: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 955: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 956: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 957: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 958: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 959: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 960: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 961: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 962: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 963: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 964: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 965: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 966: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 967: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 968: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "6" a'4  \note-mod "0" r4 | | %{ bar 969: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 970: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 971: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 972: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 973: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 974: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 975: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 976: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 977: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 978: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4.  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 979: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 980: %}
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
    \new Staff { \new Voice="X" { \time 4/4 g'2 a'4 r4 | | %{ bar 2: %} e'8 d'8 r2. | | %{ bar 3: %} c''2 c''4 r4 | | %{ bar 4: %} R1 | | %{ bar 5: %} c'8. r2. r16 | | %{ bar 6: %} b'8 c''8 r2. | | %{ bar 7: %} d''8 c'8 r2. | | %{ bar 8: %} R1 | | %{ bar 9: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 10: %} R1 | | %{ bar 11: %} R1 | | %{ bar 12: %} c'8 e'4. c''4 r4 | | %{ bar 13: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 14: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 15: %} R1 | | %{ bar 16: %} g'2 a'4 r4 | | %{ bar 17: %} e'8 c''2 c''4 r8 | | %{ bar 18: %} R1 | | %{ bar 19: %} c'8. r2. r16 | | %{ bar 20: %} b'8 c''8 r2. | | %{ bar 21: %} d''8 c'8 r2. | | %{ bar 22: %} R1 | | %{ bar 23: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 24: %} R1 | | %{ bar 25: %} R1 | | %{ bar 26: %} c'8 e'4. c''4 r4 | | %{ bar 27: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 28: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 29: %} R1 | | %{ bar 30: %} g'2 a'4 r4 | | %{ bar 31: %} e'8 c''2 c''4 r8 | | %{ bar 32: %} R1 | | %{ bar 33: %} c'8. r2. r16 | | %{ bar 34: %} b'8 c''8 r2. | | %{ bar 35: %} d''8 c'8 r2. | | %{ bar 36: %} R1 | | %{ bar 37: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 38: %} R1 | | %{ bar 39: %} R1 | | %{ bar 40: %} c'8 e'4. c''4 r4 | | %{ bar 41: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 42: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 43: %} R1 | | %{ bar 44: %} g'2 a'4 r4 | | %{ bar 45: %} e'8 c''2 c''4 r8 | | %{ bar 46: %} R1 | | %{ bar 47: %} c'8. r2. r16 | | %{ bar 48: %} b'8 c''8 r2. | | %{ bar 49: %} d''8 c'8 r2. | | %{ bar 50: %} R1 | | %{ bar 51: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 52: %} R1 | | %{ bar 53: %} R1 | | %{ bar 54: %} c'8 e'4. c''4 r4 | | %{ bar 55: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 56: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 57: %} R1 | | %{ bar 58: %} g'2 a'4 r4 | | %{ bar 59: %} e'8 c''2 c''4 r8 | | %{ bar 60: %} R1 | | %{ bar 61: %} c'8. r2. r16 | | %{ bar 62: %} b'8 c''8 r2. | | %{ bar 63: %} d''8 c'8 r2. | | %{ bar 64: %} R1 | | %{ bar 65: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 66: %} R1 | | %{ bar 67: %} R1 | | %{ bar 68: %} c'8 e'4. c''4 r4 | | %{ bar 69: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 70: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 71: %} R1 | | %{ bar 72: %} g'2 a'4 r4 | | %{ bar 73: %} e'8 c''2 c''4 r8 | | %{ bar 74: %} R1 | | %{ bar 75: %} c'8. r2. r16 | | %{ bar 76: %} b'8 c''8 r2. | | %{ bar 77: %} d''8 c'8 r2. | | %{ bar 78: %} R1 | | %{ bar 79: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 80: %} R1 | | %{ bar 81: %} R1 | | %{ bar 82: %} c'8 e'4. c''4 r4 | | %{ bar 83: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 84: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 85: %} R1 | | %{ bar 86: %} g'2 a'4 r4 | | %{ bar 87: %} e'8 c''2 c''4 r8 | | %{ bar 88: %} R1 | | %{ bar 89: %} c'8. r2. r16 | | %{ bar 90: %} b'8 c''8 r2. | | %{ bar 91: %} d''8 c'8 r2. | | %{ bar 92: %} R1 | | %{ bar 93: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 94: %} R1 | | %{ bar 95: %} R1 | | %{ bar 96: %} c'8 e'4. c''4 r4 | | %{ bar 97: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 98: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 99: %} R1 | | %{ bar 100: %} g'2 a'4 r4 | | %{ bar 101: %} e'8 c''2 c''4 r8 | | %{ bar 102: %} R1 | | %{ bar 103: %} c'8. r2. r16 | | %{ bar 104: %} b'8 c''8 r2. | | %{ bar 105: %} d''8 c'8 r2. | | %{ bar 106: %} R1 | | %{ bar 107: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 108: %} R1 | | %{ bar 109: %} R1 | | %{ bar 110: %} c'8 e'4. c''4 r4 | | %{ bar 111: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 112: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 113: %} R1 | | %{ bar 114: %} g'2 a'4 r4 | | %{ bar 115: %} e'8 c''2 c''4 r8 | | %{ bar 116: %} R1 | | %{ bar 117: %} c'8. r2. r16 | | %{ bar 118: %} b'8 c''8 r2. | | %{ bar 119: %} d''8 c'8 r2. | | %{ bar 120: %} R1 | | %{ bar 121: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 122: %} R1 | | %{ bar 123: %} R1 | | %{ bar 124: %} c'8 e'4. c''4 r4 | | %{ bar 125: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 126: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 127: %} R1 | | %{ bar 128: %} g'2 a'4 r4 | | %{ bar 129: %} e'8 c''2 c''4 r8 | | %{ bar 130: %} R1 | | %{ bar 131: %} c'8. r2. r16 | | %{ bar 132: %} b'8 c''8 r2. | | %{ bar 133: %} d''8 c'8 r2. | | %{ bar 134: %} R1 | | %{ bar 135: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 136: %} R1 | | %{ bar 137: %} R1 | | %{ bar 138: %} c'8 e'4. c''4 r4 | | %{ bar 139: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 140: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 141: %} R1 | | %{ bar 142: %} g'2 a'4 r4 | | %{ bar 143: %} e'8 c''2 c''4 r8 | | %{ bar 144: %} R1 | | %{ bar 145: %} c'8. r2. r16 | | %{ bar 146: %} b'8 c''8 r2. | | %{ bar 147: %} d''8 c'8 r2. | | %{ bar 148: %} R1 | | %{ bar 149: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 150: %} R1 | | %{ bar 151: %} R1 | | %{ bar 152: %} c'8 e'4. c''4 r4 | | %{ bar 153: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 154: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 155: %} R1 | | %{ bar 156: %} g'2 a'4 r4 | | %{ bar 157: %} e'8 c''2 c''4 r8 | | %{ bar 158: %} R1 | | %{ bar 159: %} c'8. r2. r16 | | %{ bar 160: %} b'8 c''8 r2. | | %{ bar 161: %} d''8 c'8 r2. | | %{ bar 162: %} R1 | | %{ bar 163: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 164: %} R1 | | %{ bar 165: %} R1 | | %{ bar 166: %} c'8 e'4. c''4 r4 | | %{ bar 167: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 168: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 169: %} R1 | | %{ bar 170: %} g'2 a'4 r4 | | %{ bar 171: %} e'8 c''2 c''4 r8 | | %{ bar 172: %} R1 | | %{ bar 173: %} c'8. r2. r16 | | %{ bar 174: %} b'8 c''8 r2. | | %{ bar 175: %} d''8 c'8 r2. | | %{ bar 176: %} R1 | | %{ bar 177: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 178: %} R1 | | %{ bar 179: %} R1 | | %{ bar 180: %} c'8 e'4. c''4 r4 | | %{ bar 181: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 182: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 183: %} R1 | | %{ bar 184: %} g'2 a'4 r4 | | %{ bar 185: %} e'8 c''2 c''4 r8 | | %{ bar 186: %} R1 | | %{ bar 187: %} c'8. r2. r16 | | %{ bar 188: %} b'8 c''8 r2. | | %{ bar 189: %} d''8 c'8 r2. | | %{ bar 190: %} R1 | | %{ bar 191: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 192: %} R1 | | %{ bar 193: %} R1 | | %{ bar 194: %} c'8 e'4. c''4 r4 | | %{ bar 195: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 196: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 197: %} R1 | | %{ bar 198: %} g'2 a'4 r4 | | %{ bar 199: %} e'8 c''2 c''4 r8 | | %{ bar 200: %} R1 | | %{ bar 201: %} c'8. r2. r16 | | %{ bar 202: %} b'8 c''8 r2. | | %{ bar 203: %} d''8 c'8 r2. | | %{ bar 204: %} R1 | | %{ bar 205: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 206: %} R1 | | %{ bar 207: %} R1 | | %{ bar 208: %} c'8 e'4. c''4 r4 | | %{ bar 209: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 210: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 211: %} R1 | | %{ bar 212: %} g'2 a'4 r4 | | %{ bar 213: %} e'8 c''2 c''4 r8 | | %{ bar 214: %} R1 | | %{ bar 215: %} c'8. r2. r16 | | %{ bar 216: %} b'8 c''8 r2. | | %{ bar 217: %} d''8 c'8 r2. | | %{ bar 218: %} R1 | | %{ bar 219: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 220: %} R1 | | %{ bar 221: %} R1 | | %{ bar 222: %} c'8 e'4. c''4 r4 | | %{ bar 223: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 224: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 225: %} R1 | | %{ bar 226: %} g'2 a'4 r4 | | %{ bar 227: %} e'8 c''2 c''4 r8 | | %{ bar 228: %} R1 | | %{ bar 229: %} c'8. r2. r16 | | %{ bar 230: %} b'8 c''8 r2. | | %{ bar 231: %} d''8 c'8 r2. | | %{ bar 232: %} R1 | | %{ bar 233: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 234: %} R1 | | %{ bar 235: %} R1 | | %{ bar 236: %} c'8 e'4. c''4 r4 | | %{ bar 237: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 238: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 239: %} R1 | | %{ bar 240: %} g'2 a'4 r4 | | %{ bar 241: %} e'8 c''2 c''4 r8 | | %{ bar 242: %} R1 | | %{ bar 243: %} c'8. r2. r16 | | %{ bar 244: %} b'8 c''8 r2. | | %{ bar 245: %} d''8 c'8 r2. | | %{ bar 246: %} R1 | | %{ bar 247: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 248: %} R1 | | %{ bar 249: %} R1 | | %{ bar 250: %} c'8 e'4. c''4 r4 | | %{ bar 251: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 252: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 253: %} R1 | | %{ bar 254: %} g'2 a'4 r4 | | %{ bar 255: %} e'8 c''2 c''4 r8 | | %{ bar 256: %} R1 | | %{ bar 257: %} c'8. r2. r16 | | %{ bar 258: %} b'8 c''8 r2. | | %{ bar 259: %} d''8 c'8 r2. | | %{ bar 260: %} R1 | | %{ bar 261: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 262: %} R1 | | %{ bar 263: %} R1 | | %{ bar 264: %} c'8 e'4. c''4 r4 | | %{ bar 265: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 266: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 267: %} R1 | | %{ bar 268: %} g'2 a'4 r4 | | %{ bar 269: %} e'8 c''2 c''4 r8 | | %{ bar 270: %} R1 | | %{ bar 271: %} c'8. r2. r16 | | %{ bar 272: %} b'8 c''8 r2. | | %{ bar 273: %} d''8 c'8 r2. | | %{ bar 274: %} R1 | | %{ bar 275: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 276: %} R1 | | %{ bar 277: %} R1 | | %{ bar 278: %} c'8 e'4. c''4 r4 | | %{ bar 279: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 280: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 281: %} R1 | | %{ bar 282: %} g'2 a'4 r4 | | %{ bar 283: %} e'8 c''2 c''4 r8 | | %{ bar 284: %} R1 | | %{ bar 285: %} c'8. r2. r16 | | %{ bar 286: %} b'8 c''8 r2. | | %{ bar 287: %} d''8 c'8 r2. | | %{ bar 288: %} R1 | | %{ bar 289: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 290: %} R1 | | %{ bar 291: %} R1 | | %{ bar 292: %} c'8 e'4. c''4 r4 | | %{ bar 293: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 294: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 295: %} R1 | | %{ bar 296: %} g'2 a'4 r4 | | %{ bar 297: %} e'8 c''2 c''4 r8 | | %{ bar 298: %} R1 | | %{ bar 299: %} c'8. r2. r16 | | %{ bar 300: %} b'8 c''8 r2. | | %{ bar 301: %} d''8 c'8 r2. | | %{ bar 302: %} R1 | | %{ bar 303: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 304: %} R1 | | %{ bar 305: %} R1 | | %{ bar 306: %} c'8 e'4. c''4 r4 | | %{ bar 307: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 308: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 309: %} R1 | | %{ bar 310: %} g'2 a'4 r4 | | %{ bar 311: %} e'8 c''2 c''4 r8 | | %{ bar 312: %} R1 | | %{ bar 313: %} c'8. r2. r16 | | %{ bar 314: %} b'8 c''8 r2. | | %{ bar 315: %} d''8 c'8 r2. | | %{ bar 316: %} R1 | | %{ bar 317: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 318: %} R1 | | %{ bar 319: %} R1 | | %{ bar 320: %} c'8 e'4. c''4 r4 | | %{ bar 321: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 322: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 323: %} R1 | | %{ bar 324: %} g'2 a'4 r4 | | %{ bar 325: %} e'8 c''2 c''4 r8 | | %{ bar 326: %} R1 | | %{ bar 327: %} c'8. r2. r16 | | %{ bar 328: %} b'8 c''8 r2. | | %{ bar 329: %} d''8 c'8 r2. | | %{ bar 330: %} R1 | | %{ bar 331: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 332: %} R1 | | %{ bar 333: %} R1 | | %{ bar 334: %} c'8 e'4. c''4 r4 | | %{ bar 335: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 336: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 337: %} R1 | | %{ bar 338: %} g'2 a'4 r4 | | %{ bar 339: %} e'8 c''2 c''4 r8 | | %{ bar 340: %} R1 | | %{ bar 341: %} c'8. r2. r16 | | %{ bar 342: %} b'8 c''8 r2. | | %{ bar 343: %} d''8 c'8 r2. | | %{ bar 344: %} R1 | | %{ bar 345: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 346: %} R1 | | %{ bar 347: %} R1 | | %{ bar 348: %} c'8 e'4. c''4 r4 | | %{ bar 349: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 350: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 351: %} R1 | | %{ bar 352: %} g'2 a'4 r4 | | %{ bar 353: %} e'8 c''2 c''4 r8 | | %{ bar 354: %} R1 | | %{ bar 355: %} c'8. r2. r16 | | %{ bar 356: %} b'8 c''8 r2. | | %{ bar 357: %} d''8 c'8 r2. | | %{ bar 358: %} R1 | | %{ bar 359: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 360: %} R1 | | %{ bar 361: %} R1 | | %{ bar 362: %} c'8 e'4. c''4 r4 | | %{ bar 363: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 364: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 365: %} R1 | | %{ bar 366: %} g'2 a'4 r4 | | %{ bar 367: %} e'8 c''2 c''4 r8 | | %{ bar 368: %} R1 | | %{ bar 369: %} c'8. r2. r16 | | %{ bar 370: %} b'8 c''8 r2. | | %{ bar 371: %} d''8 c'8 r2. | | %{ bar 372: %} R1 | | %{ bar 373: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 374: %} R1 | | %{ bar 375: %} R1 | | %{ bar 376: %} c'8 e'4. c''4 r4 | | %{ bar 377: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 378: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 379: %} R1 | | %{ bar 380: %} g'2 a'4 r4 | | %{ bar 381: %} e'8 c''2 c''4 r8 | | %{ bar 382: %} R1 | | %{ bar 383: %} c'8. r2. r16 | | %{ bar 384: %} b'8 c''8 r2. | | %{ bar 385: %} d''8 c'8 r2. | | %{ bar 386: %} R1 | | %{ bar 387: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 388: %} R1 | | %{ bar 389: %} R1 | | %{ bar 390: %} c'8 e'4. c''4 r4 | | %{ bar 391: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 392: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 393: %} R1 | | %{ bar 394: %} g'2 a'4 r4 | | %{ bar 395: %} e'8 c''2 c''4 r8 | | %{ bar 396: %} R1 | | %{ bar 397: %} c'8. r2. r16 | | %{ bar 398: %} b'8 c''8 r2. | | %{ bar 399: %} d''8 c'8 r2. | | %{ bar 400: %} R1 | | %{ bar 401: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 402: %} R1 | | %{ bar 403: %} R1 | | %{ bar 404: %} c'8 e'4. c''4 r4 | | %{ bar 405: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 406: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 407: %} R1 | | %{ bar 408: %} g'2 a'4 r4 | | %{ bar 409: %} e'8 c''2 c''4 r8 | | %{ bar 410: %} R1 | | %{ bar 411: %} c'8. r2. r16 | | %{ bar 412: %} b'8 c''8 r2. | | %{ bar 413: %} d''8 c'8 r2. | | %{ bar 414: %} R1 | | %{ bar 415: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 416: %} R1 | | %{ bar 417: %} R1 | | %{ bar 418: %} c'8 e'4. c''4 r4 | | %{ bar 419: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 420: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 421: %} R1 | | %{ bar 422: %} g'2 a'4 r4 | | %{ bar 423: %} e'8 c''2 c''4 r8 | | %{ bar 424: %} R1 | | %{ bar 425: %} c'8. r2. r16 | | %{ bar 426: %} b'8 c''8 r2. | | %{ bar 427: %} d''8 c'8 r2. | | %{ bar 428: %} R1 | | %{ bar 429: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 430: %} R1 | | %{ bar 431: %} R1 | | %{ bar 432: %} c'8 e'4. c''4 r4 | | %{ bar 433: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 434: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 435: %} R1 | | %{ bar 436: %} g'2 a'4 r4 | | %{ bar 437: %} e'8 c''2 c''4 r8 | | %{ bar 438: %} R1 | | %{ bar 439: %} c'8. r2. r16 | | %{ bar 440: %} b'8 c''8 r2. | | %{ bar 441: %} d''8 c'8 r2. | | %{ bar 442: %} R1 | | %{ bar 443: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 444: %} R1 | | %{ bar 445: %} R1 | | %{ bar 446: %} c'8 e'4. c''4 r4 | | %{ bar 447: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 448: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 449: %} R1 | | %{ bar 450: %} g'2 a'4 r4 | | %{ bar 451: %} e'8 c''2 c''4 r8 | | %{ bar 452: %} R1 | | %{ bar 453: %} c'8. r2. r16 | | %{ bar 454: %} b'8 c''8 r2. | | %{ bar 455: %} d''8 c'8 r2. | | %{ bar 456: %} R1 | | %{ bar 457: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 458: %} R1 | | %{ bar 459: %} R1 | | %{ bar 460: %} c'8 e'4. c''4 r4 | | %{ bar 461: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 462: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 463: %} R1 | | %{ bar 464: %} g'2 a'4 r4 | | %{ bar 465: %} e'8 c''2 c''4 r8 | | %{ bar 466: %} R1 | | %{ bar 467: %} c'8. r2. r16 | | %{ bar 468: %} b'8 c''8 r2. | | %{ bar 469: %} d''8 c'8 r2. | | %{ bar 470: %} R1 | | %{ bar 471: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 472: %} R1 | | %{ bar 473: %} R1 | | %{ bar 474: %} c'8 e'4. c''4 r4 | | %{ bar 475: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 476: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 477: %} R1 | | %{ bar 478: %} g'2 a'4 r4 | | %{ bar 479: %} e'8 c''2 c''4 r8 | | %{ bar 480: %} R1 | | %{ bar 481: %} c'8. r2. r16 | | %{ bar 482: %} b'8 c''8 r2. | | %{ bar 483: %} d''8 c'8 r2. | | %{ bar 484: %} R1 | | %{ bar 485: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 486: %} R1 | | %{ bar 487: %} R1 | | %{ bar 488: %} c'8 e'4. c''4 r4 | | %{ bar 489: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 490: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 491: %} R1 | | %{ bar 492: %} g'2 a'4 r4 | | %{ bar 493: %} e'8 c''2 c''4 r8 | | %{ bar 494: %} R1 | | %{ bar 495: %} c'8. r2. r16 | | %{ bar 496: %} b'8 c''8 r2. | | %{ bar 497: %} d''8 c'8 r2. | | %{ bar 498: %} R1 | | %{ bar 499: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 500: %} R1 | | %{ bar 501: %} R1 | | %{ bar 502: %} c'8 e'4. c''4 r4 | | %{ bar 503: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 504: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 505: %} R1 | | %{ bar 506: %} g'2 a'4 r4 | | %{ bar 507: %} e'8 c''2 c''4 r8 | | %{ bar 508: %} R1 | | %{ bar 509: %} c'8. r2. r16 | | %{ bar 510: %} b'8 c''8 r2. | | %{ bar 511: %} d''8 c'8 r2. | | %{ bar 512: %} R1 | | %{ bar 513: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 514: %} R1 | | %{ bar 515: %} R1 | | %{ bar 516: %} c'8 e'4. c''4 r4 | | %{ bar 517: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 518: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 519: %} R1 | | %{ bar 520: %} g'2 a'4 r4 | | %{ bar 521: %} e'8 c''2 c''4 r8 | | %{ bar 522: %} R1 | | %{ bar 523: %} c'8. r2. r16 | | %{ bar 524: %} b'8 c''8 r2. | | %{ bar 525: %} d''8 c'8 r2. | | %{ bar 526: %} R1 | | %{ bar 527: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 528: %} R1 | | %{ bar 529: %} R1 | | %{ bar 530: %} c'8 e'4. c''4 r4 | | %{ bar 531: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 532: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 533: %} R1 | | %{ bar 534: %} g'2 a'4 r4 | | %{ bar 535: %} e'8 c''2 c''4 r8 | | %{ bar 536: %} R1 | | %{ bar 537: %} c'8. r2. r16 | | %{ bar 538: %} b'8 c''8 r2. | | %{ bar 539: %} d''8 c'8 r2. | | %{ bar 540: %} R1 | | %{ bar 541: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 542: %} R1 | | %{ bar 543: %} R1 | | %{ bar 544: %} c'8 e'4. c''4 r4 | | %{ bar 545: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 546: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 547: %} R1 | | %{ bar 548: %} g'2 a'4 r4 | | %{ bar 549: %} e'8 c''2 c''4 r8 | | %{ bar 550: %} R1 | | %{ bar 551: %} c'8. r2. r16 | | %{ bar 552: %} b'8 c''8 r2. | | %{ bar 553: %} d''8 c'8 r2. | | %{ bar 554: %} R1 | | %{ bar 555: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 556: %} R1 | | %{ bar 557: %} R1 | | %{ bar 558: %} c'8 e'4. c''4 r4 | | %{ bar 559: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 560: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 561: %} R1 | | %{ bar 562: %} g'2 a'4 r4 | | %{ bar 563: %} e'8 c''2 c''4 r8 | | %{ bar 564: %} R1 | | %{ bar 565: %} c'8. r2. r16 | | %{ bar 566: %} b'8 c''8 r2. | | %{ bar 567: %} d''8 c'8 r2. | | %{ bar 568: %} R1 | | %{ bar 569: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 570: %} R1 | | %{ bar 571: %} R1 | | %{ bar 572: %} c'8 e'4. c''4 r4 | | %{ bar 573: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 574: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 575: %} R1 | | %{ bar 576: %} g'2 a'4 r4 | | %{ bar 577: %} e'8 c''2 c''4 r8 | | %{ bar 578: %} R1 | | %{ bar 579: %} c'8. r2. r16 | | %{ bar 580: %} b'8 c''8 r2. | | %{ bar 581: %} d''8 c'8 r2. | | %{ bar 582: %} R1 | | %{ bar 583: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 584: %} R1 | | %{ bar 585: %} R1 | | %{ bar 586: %} c'8 e'4. c''4 r4 | | %{ bar 587: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 588: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 589: %} R1 | | %{ bar 590: %} g'2 a'4 r4 | | %{ bar 591: %} e'8 c''2 c''4 r8 | | %{ bar 592: %} R1 | | %{ bar 593: %} c'8. r2. r16 | | %{ bar 594: %} b'8 c''8 r2. | | %{ bar 595: %} d''8 c'8 r2. | | %{ bar 596: %} R1 | | %{ bar 597: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 598: %} R1 | | %{ bar 599: %} R1 | | %{ bar 600: %} c'8 e'4. c''4 r4 | | %{ bar 601: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 602: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 603: %} R1 | | %{ bar 604: %} g'2 a'4 r4 | | %{ bar 605: %} e'8 c''2 c''4 r8 | | %{ bar 606: %} R1 | | %{ bar 607: %} c'8. r2. r16 | | %{ bar 608: %} b'8 c''8 r2. | | %{ bar 609: %} d''8 c'8 r2. | | %{ bar 610: %} R1 | | %{ bar 611: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 612: %} R1 | | %{ bar 613: %} R1 | | %{ bar 614: %} c'8 e'4. c''4 r4 | | %{ bar 615: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 616: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 617: %} R1 | | %{ bar 618: %} g'2 a'4 r4 | | %{ bar 619: %} e'8 c''2 c''4 r8 | | %{ bar 620: %} R1 | | %{ bar 621: %} c'8. r2. r16 | | %{ bar 622: %} b'8 c''8 r2. | | %{ bar 623: %} d''8 c'8 r2. | | %{ bar 624: %} R1 | | %{ bar 625: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 626: %} R1 | | %{ bar 627: %} R1 | | %{ bar 628: %} c'8 e'4. c''4 r4 | | %{ bar 629: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 630: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 631: %} R1 | | %{ bar 632: %} g'2 a'4 r4 | | %{ bar 633: %} e'8 c''2 c''4 r8 | | %{ bar 634: %} R1 | | %{ bar 635: %} c'8. r2. r16 | | %{ bar 636: %} b'8 c''8 r2. | | %{ bar 637: %} d''8 c'8 r2. | | %{ bar 638: %} R1 | | %{ bar 639: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 640: %} R1 | | %{ bar 641: %} R1 | | %{ bar 642: %} c'8 e'4. c''4 r4 | | %{ bar 643: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 644: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 645: %} R1 | | %{ bar 646: %} g'2 a'4 r4 | | %{ bar 647: %} e'8 c''2 c''4 r8 | | %{ bar 648: %} R1 | | %{ bar 649: %} c'8. r2. r16 | | %{ bar 650: %} b'8 c''8 r2. | | %{ bar 651: %} d''8 c'8 r2. | | %{ bar 652: %} R1 | | %{ bar 653: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 654: %} R1 | | %{ bar 655: %} R1 | | %{ bar 656: %} c'8 e'4. c''4 r4 | | %{ bar 657: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 658: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 659: %} R1 | | %{ bar 660: %} g'2 a'4 r4 | | %{ bar 661: %} e'8 c''2 c''4 r8 | | %{ bar 662: %} R1 | | %{ bar 663: %} c'8. r2. r16 | | %{ bar 664: %} b'8 c''8 r2. | | %{ bar 665: %} d''8 c'8 r2. | | %{ bar 666: %} R1 | | %{ bar 667: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 668: %} R1 | | %{ bar 669: %} R1 | | %{ bar 670: %} c'8 e'4. c''4 r4 | | %{ bar 671: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 672: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 673: %} R1 | | %{ bar 674: %} g'2 a'4 r4 | | %{ bar 675: %} e'8 c''2 c''4 r8 | | %{ bar 676: %} R1 | | %{ bar 677: %} c'8. r2. r16 | | %{ bar 678: %} b'8 c''8 r2. | | %{ bar 679: %} d''8 c'8 r2. | | %{ bar 680: %} R1 | | %{ bar 681: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 682: %} R1 | | %{ bar 683: %} R1 | | %{ bar 684: %} c'8 e'4. c''4 r4 | | %{ bar 685: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 686: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 687: %} R1 | | %{ bar 688: %} g'2 a'4 r4 | | %{ bar 689: %} e'8 c''2 c''4 r8 | | %{ bar 690: %} R1 | | %{ bar 691: %} c'8. r2. r16 | | %{ bar 692: %} b'8 c''8 r2. | | %{ bar 693: %} d''8 c'8 r2. | | %{ bar 694: %} R1 | | %{ bar 695: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 696: %} R1 | | %{ bar 697: %} R1 | | %{ bar 698: %} c'8 e'4. c''4 r4 | | %{ bar 699: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 700: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 701: %} R1 | | %{ bar 702: %} g'2 a'4 r4 | | %{ bar 703: %} e'8 c''2 c''4 r8 | | %{ bar 704: %} R1 | | %{ bar 705: %} c'8. r2. r16 | | %{ bar 706: %} b'8 c''8 r2. | | %{ bar 707: %} d''8 c'8 r2. | | %{ bar 708: %} R1 | | %{ bar 709: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 710: %} R1 | | %{ bar 711: %} R1 | | %{ bar 712: %} c'8 e'4. c''4 r4 | | %{ bar 713: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 714: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 715: %} R1 | | %{ bar 716: %} g'2 a'4 r4 | | %{ bar 717: %} e'8 c''2 c''4 r8 | | %{ bar 718: %} R1 | | %{ bar 719: %} c'8. r2. r16 | | %{ bar 720: %} b'8 c''8 r2. | | %{ bar 721: %} d''8 c'8 r2. | | %{ bar 722: %} R1 | | %{ bar 723: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 724: %} R1 | | %{ bar 725: %} R1 | | %{ bar 726: %} c'8 e'4. c''4 r4 | | %{ bar 727: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 728: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 729: %} R1 | | %{ bar 730: %} g'2 a'4 r4 | | %{ bar 731: %} e'8 c''2 c''4 r8 | | %{ bar 732: %} R1 | | %{ bar 733: %} c'8. r2. r16 | | %{ bar 734: %} b'8 c''8 r2. | | %{ bar 735: %} d''8 c'8 r2. | | %{ bar 736: %} R1 | | %{ bar 737: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 738: %} R1 | | %{ bar 739: %} R1 | | %{ bar 740: %} c'8 e'4. c''4 r4 | | %{ bar 741: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 742: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 743: %} R1 | | %{ bar 744: %} g'2 a'4 r4 | | %{ bar 745: %} e'8 c''2 c''4 r8 | | %{ bar 746: %} R1 | | %{ bar 747: %} c'8. r2. r16 | | %{ bar 748: %} b'8 c''8 r2. | | %{ bar 749: %} d''8 c'8 r2. | | %{ bar 750: %} R1 | | %{ bar 751: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 752: %} R1 | | %{ bar 753: %} R1 | | %{ bar 754: %} c'8 e'4. c''4 r4 | | %{ bar 755: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 756: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 757: %} R1 | | %{ bar 758: %} g'2 a'4 r4 | | %{ bar 759: %} e'8 c''2 c''4 r8 | | %{ bar 760: %} R1 | | %{ bar 761: %} c'8. r2. r16 | | %{ bar 762: %} b'8 c''8 r2. | | %{ bar 763: %} d''8 c'8 r2. | | %{ bar 764: %} R1 | | %{ bar 765: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 766: %} R1 | | %{ bar 767: %} R1 | | %{ bar 768: %} c'8 e'4. c''4 r4 | | %{ bar 769: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 770: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 771: %} R1 | | %{ bar 772: %} g'2 a'4 r4 | | %{ bar 773: %} e'8 c''2 c''4 r8 | | %{ bar 774: %} R1 | | %{ bar 775: %} c'8. r2. r16 | | %{ bar 776: %} b'8 c''8 r2. | | %{ bar 777: %} d''8 c'8 r2. | | %{ bar 778: %} R1 | | %{ bar 779: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 780: %} R1 | | %{ bar 781: %} R1 | | %{ bar 782: %} c'8 e'4. c''4 r4 | | %{ bar 783: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 784: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 785: %} R1 | | %{ bar 786: %} g'2 a'4 r4 | | %{ bar 787: %} e'8 c''2 c''4 r8 | | %{ bar 788: %} R1 | | %{ bar 789: %} c'8. r2. r16 | | %{ bar 790: %} b'8 c''8 r2. | | %{ bar 791: %} d''8 c'8 r2. | | %{ bar 792: %} R1 | | %{ bar 793: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 794: %} R1 | | %{ bar 795: %} R1 | | %{ bar 796: %} c'8 e'4. c''4 r4 | | %{ bar 797: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 798: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 799: %} R1 | | %{ bar 800: %} g'2 a'4 r4 | | %{ bar 801: %} e'8 c''2 c''4 r8 | | %{ bar 802: %} R1 | | %{ bar 803: %} c'8. r2. r16 | | %{ bar 804: %} b'8 c''8 r2. | | %{ bar 805: %} d''8 c'8 r2. | | %{ bar 806: %} R1 | | %{ bar 807: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 808: %} R1 | | %{ bar 809: %} R1 | | %{ bar 810: %} c'8 e'4. c''4 r4 | | %{ bar 811: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 812: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 813: %} R1 | | %{ bar 814: %} g'2 a'4 r4 | | %{ bar 815: %} e'8 c''2 c''4 r8 | | %{ bar 816: %} R1 | | %{ bar 817: %} c'8. r2. r16 | | %{ bar 818: %} b'8 c''8 r2. | | %{ bar 819: %} d''8 c'8 r2. | | %{ bar 820: %} R1 | | %{ bar 821: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 822: %} R1 | | %{ bar 823: %} R1 | | %{ bar 824: %} c'8 e'4. c''4 r4 | | %{ bar 825: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 826: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 827: %} R1 | | %{ bar 828: %} g'2 a'4 r4 | | %{ bar 829: %} e'8 c''2 c''4 r8 | | %{ bar 830: %} R1 | | %{ bar 831: %} c'8. r2. r16 | | %{ bar 832: %} b'8 c''8 r2. | | %{ bar 833: %} d''8 c'8 r2. | | %{ bar 834: %} R1 | | %{ bar 835: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 836: %} R1 | | %{ bar 837: %} R1 | | %{ bar 838: %} c'8 e'4. c''4 r4 | | %{ bar 839: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 840: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 841: %} R1 | | %{ bar 842: %} g'2 a'4 r4 | | %{ bar 843: %} e'8 c''2 c''4 r8 | | %{ bar 844: %} R1 | | %{ bar 845: %} c'8. r2. r16 | | %{ bar 846: %} b'8 c''8 r2. | | %{ bar 847: %} d''8 c'8 r2. | | %{ bar 848: %} R1 | | %{ bar 849: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 850: %} R1 | | %{ bar 851: %} R1 | | %{ bar 852: %} c'8 e'4. c''4 r4 | | %{ bar 853: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 854: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 855: %} R1 | | %{ bar 856: %} g'2 a'4 r4 | | %{ bar 857: %} e'8 c''2 c''4 r8 | | %{ bar 858: %} R1 | | %{ bar 859: %} c'8. r2. r16 | | %{ bar 860: %} b'8 c''8 r2. | | %{ bar 861: %} d''8 c'8 r2. | | %{ bar 862: %} R1 | | %{ bar 863: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 864: %} R1 | | %{ bar 865: %} R1 | | %{ bar 866: %} c'8 e'4. c''4 r4 | | %{ bar 867: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 868: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 869: %} R1 | | %{ bar 870: %} g'2 a'4 r4 | | %{ bar 871: %} e'8 c''2 c''4 r8 | | %{ bar 872: %} R1 | | %{ bar 873: %} c'8. r2. r16 | | %{ bar 874: %} b'8 c''8 r2. | | %{ bar 875: %} d''8 c'8 r2. | | %{ bar 876: %} R1 | | %{ bar 877: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 878: %} R1 | | %{ bar 879: %} R1 | | %{ bar 880: %} c'8 e'4. c''4 r4 | | %{ bar 881: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 882: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 883: %} R1 | | %{ bar 884: %} g'2 a'4 r4 | | %{ bar 885: %} e'8 c''2 c''4 r8 | | %{ bar 886: %} R1 | | %{ bar 887: %} c'8. r2. r16 | | %{ bar 888: %} b'8 c''8 r2. | | %{ bar 889: %} d''8 c'8 r2. | | %{ bar 890: %} R1 | | %{ bar 891: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 892: %} R1 | | %{ bar 893: %} R1 | | %{ bar 894: %} c'8 e'4. c''4 r4 | | %{ bar 895: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 896: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 897: %} R1 | | %{ bar 898: %} g'2 a'4 r4 | | %{ bar 899: %} e'8 c''2 c''4 r8 | | %{ bar 900: %} R1 | | %{ bar 901: %} c'8. r2. r16 | | %{ bar 902: %} b'8 c''8 r2. | | %{ bar 903: %} d''8 c'8 r2. | | %{ bar 904: %} R1 | | %{ bar 905: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 906: %} R1 | | %{ bar 907: %} R1 | | %{ bar 908: %} c'8 e'4. c''4 r4 | | %{ bar 909: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 910: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 911: %} R1 | | %{ bar 912: %} g'2 a'4 r4 | | %{ bar 913: %} e'8 c''2 c''4 r8 | | %{ bar 914: %} R1 | | %{ bar 915: %} c'8. r2. r16 | | %{ bar 916: %} b'8 c''8 r2. | | %{ bar 917: %} d''8 c'8 r2. | | %{ bar 918: %} R1 | | %{ bar 919: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 920: %} R1 | | %{ bar 921: %} R1 | | %{ bar 922: %} c'8 e'4. c''4 r4 | | %{ bar 923: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 924: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 925: %} R1 | | %{ bar 926: %} g'2 a'4 r4 | | %{ bar 927: %} e'8 c''2 c''4 r8 | | %{ bar 928: %} R1 | | %{ bar 929: %} c'8. r2. r16 | | %{ bar 930: %} b'8 c''8 r2. | | %{ bar 931: %} d''8 c'8 r2. | | %{ bar 932: %} R1 | | %{ bar 933: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 934: %} R1 | | %{ bar 935: %} R1 | | %{ bar 936: %} c'8 e'4. c''4 r4 | | %{ bar 937: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 938: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 939: %} R1 | | %{ bar 940: %} g'2 a'4 r4 | | %{ bar 941: %} e'8 c''2 c''4 r8 | | %{ bar 942: %} R1 | | %{ bar 943: %} c'8. r2. r16 | | %{ bar 944: %} b'8 c''8 r2. | | %{ bar 945: %} d''8 c'8 r2. | | %{ bar 946: %} R1 | | %{ bar 947: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 948: %} R1 | | %{ bar 949: %} R1 | | %{ bar 950: %} c'8 e'4. c''4 r4 | | %{ bar 951: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 952: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 953: %} R1 | | %{ bar 954: %} g'2 a'4 r4 | | %{ bar 955: %} e'8 c''2 c''4 r8 | | %{ bar 956: %} R1 | | %{ bar 957: %} c'8. r2. r16 | | %{ bar 958: %} b'8 c''8 r2. | | %{ bar 959: %} d''8 c'8 r2. | | %{ bar 960: %} R1 | | %{ bar 961: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 962: %} R1 | | %{ bar 963: %} R1 | | %{ bar 964: %} c'8 e'4. c''4 r4 | | %{ bar 965: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 966: %} c'8 a'4. c'8 b'4 r8 | | %{ bar 967: %} R1 | | %{ bar 968: %} g'2 a'4 r4 | | %{ bar 969: %} e'8 c''2 c''4 r8 | | %{ bar 970: %} R1 | | %{ bar 971: %} c'8. r2. r16 | | %{ bar 972: %} b'8 c''8 r2. | | %{ bar 973: %} d''8 c'8 r2. | | %{ bar 974: %} R1 | | %{ bar 975: %} c'8 c'4. c'8 d'4 r8 | | %{ bar 976: %} R1 | | %{ bar 977: %} R1 | | %{ bar 978: %} c'8 e'4. c''4 r4 | | %{ bar 979: %} c'8 f'4. c'8 g'4 r8 | | %{ bar 980: %} r1 | } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
