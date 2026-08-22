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
0 0 0 0 | q2 s3 6' 0 0 s0 | q5 - b7 6 q0 | q1 - 0 0 q0 | 0 0 0 0 |
q2 - 0 0 q0 | q3 - 0 0 q0 | - q2 - 0 q0 | 0 0 0 0 |
q2 - 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - 0 0 q0 | - q2 - - q0 | - - 0 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 q5 - q0 | q1 - 0 0 q0 |
q3 - - q2 - | - - - 0 | 0 0 0 0 |
q2 0 0 0 q0 | 0 0 0 0 |
0 0 0 0 | 0 0 0 0 | 0 0 0 0 | q4 s1' 5' 0 0 s0 | b7 6 0 0 |
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
     \time 4/4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
]   \note-mod "6" a''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 3: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4  \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 16: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 18: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 19: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 20: %}
 \note-mod "–" r4
 \note-mod "–" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 21: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 22: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 23: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 24: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 25: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 26: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 27: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 28: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 29: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 31: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 32: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 33: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 34: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 35: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 36: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 37: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 38: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 39: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 40: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 41: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 42: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 43: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 44: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 45: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 46: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 47: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 48: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 49: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 50: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 51: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 52: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 53: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 54: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 55: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 56: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 57: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 58: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 59: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 60: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 61: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 62: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 63: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 64: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 65: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 66: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 67: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 68: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 69: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 70: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 71: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 72: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 73: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 74: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 75: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 76: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 77: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 78: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 79: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 80: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 81: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 82: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 83: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 84: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 85: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 86: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 87: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 88: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 89: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 90: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 91: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 92: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 93: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 94: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 95: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 96: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 97: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 98: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 99: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 100: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 101: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 102: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 103: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 104: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 105: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 106: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 107: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 108: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 109: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 111: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 112: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 113: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 114: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 115: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 116: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 117: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 118: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 119: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 120: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 121: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 122: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 123: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 124: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 125: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 126: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 127: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 128: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 129: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 130: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 131: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 132: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 133: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 134: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 135: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 136: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 137: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 138: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 139: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 140: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 141: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 142: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 143: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 144: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 145: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 146: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 147: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 148: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 149: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 150: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 151: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 152: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 153: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 154: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 155: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 156: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 157: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 158: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 159: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 160: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 161: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 162: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 163: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 164: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 165: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 166: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 167: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 168: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 169: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 170: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 171: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 172: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 173: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 174: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 175: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 176: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 177: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 178: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 179: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 180: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 181: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 182: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 183: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 184: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 185: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 186: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 187: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 188: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 189: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 190: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 191: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 192: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 193: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 194: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 195: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 196: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 197: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 198: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 199: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 200: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 201: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 202: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 203: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 204: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 205: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 206: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 207: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 208: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 209: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 210: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 211: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 212: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 213: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 214: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 215: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 216: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 217: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 218: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 219: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 220: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 221: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 222: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 223: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 224: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 225: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 226: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 227: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 228: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 229: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 230: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 231: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 232: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 233: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 234: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 235: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 236: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 237: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 238: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 239: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 240: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 241: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 242: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 243: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 244: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 245: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 246: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 247: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 248: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 249: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 250: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 251: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 252: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 253: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 254: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 255: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 256: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 257: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 258: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 259: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 260: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 261: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 262: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 263: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 264: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 265: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 266: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 267: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 268: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 269: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 270: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 271: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 272: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 273: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 274: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 275: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 276: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 277: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 278: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 279: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 280: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 281: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 282: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 283: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 284: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 285: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 286: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 287: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 288: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 289: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 290: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 291: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 292: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 293: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 294: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 295: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 296: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 297: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 298: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 299: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 300: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 301: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 302: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 303: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 304: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 305: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 306: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 307: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 308: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 309: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 310: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 311: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 312: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 313: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 314: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 315: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 316: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 317: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 318: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 319: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 320: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 321: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 322: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 323: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 324: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 325: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 326: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 327: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 328: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 329: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 330: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 331: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 332: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 333: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 334: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 335: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 336: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 337: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 338: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 339: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 340: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 341: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 342: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 343: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 344: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 345: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 346: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 347: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 348: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 349: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 350: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 351: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 352: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 353: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 354: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 355: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 356: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 357: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 358: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 359: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 360: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 361: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 362: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 363: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 364: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 365: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 366: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 367: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 368: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 369: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 370: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 371: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 372: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 373: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 374: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 375: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 376: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 377: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 378: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 379: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 380: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 381: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 382: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 383: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 384: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 385: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 386: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 387: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 388: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 389: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 390: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 391: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 392: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 393: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 394: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 395: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 396: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 397: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 398: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 399: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 400: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 401: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 402: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 403: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 404: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 405: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 406: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 407: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 408: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 409: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 410: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 411: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 412: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 413: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 414: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 415: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 416: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 417: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 418: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 419: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 420: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 421: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 422: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 423: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 424: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 425: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 426: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 427: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 428: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 429: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 430: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 431: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 432: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 433: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 434: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 435: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 436: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 437: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 438: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 439: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 440: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 441: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 442: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 443: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 444: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 445: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 446: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 447: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 448: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 449: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 450: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 451: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 452: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 453: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 454: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 455: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 456: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 457: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 458: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 459: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 460: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 461: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 462: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 463: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 464: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 465: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 466: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 467: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 468: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 469: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 470: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 471: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 472: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 473: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 474: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 475: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 476: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 477: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 478: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 479: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 480: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 481: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 482: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 483: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 484: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 485: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 486: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 487: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 488: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 489: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 490: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 491: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 492: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 493: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 494: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 495: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 496: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 497: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 498: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 499: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 500: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 501: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 502: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 503: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 504: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 505: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 506: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 507: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 508: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 509: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 510: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 511: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 512: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 513: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 514: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 515: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 516: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 517: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 518: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 519: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 520: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 521: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 522: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 523: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 524: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 525: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 526: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 527: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 528: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 529: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 530: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 531: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 532: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 533: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 534: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 535: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 536: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 537: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 538: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 539: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 540: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 541: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 542: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 543: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 544: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 545: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 546: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 547: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 548: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 549: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 550: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 551: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 552: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 553: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 554: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 555: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 556: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 557: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 558: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 559: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 560: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 561: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 562: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 563: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 564: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 565: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 566: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 567: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 568: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 569: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 570: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 571: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 572: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 573: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 574: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 575: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 576: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 577: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 578: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 579: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 580: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 581: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 582: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 583: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 584: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 585: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 586: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 587: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 588: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 589: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 590: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 591: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 592: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 593: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 594: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 595: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 596: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 597: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 598: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 599: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 600: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 601: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 602: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 603: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 604: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 605: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 606: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 607: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 608: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 609: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 610: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 611: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 612: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 613: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 614: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 615: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 616: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 617: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 618: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 619: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 620: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 621: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 622: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 623: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 624: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 625: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 626: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 627: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 628: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 629: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 630: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 631: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 632: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 633: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 634: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 635: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 636: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 637: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 638: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 639: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 640: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 641: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 642: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 643: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 644: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 645: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 646: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 647: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 648: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 649: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 650: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 651: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 652: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 653: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 654: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 655: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 656: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 657: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 658: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 659: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 660: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 661: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 662: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 663: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 664: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 665: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 666: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 667: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 668: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 669: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 670: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 671: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 672: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 673: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 674: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 675: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 676: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 677: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 678: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 679: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 680: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 681: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 682: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 683: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 684: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 685: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 686: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 687: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 688: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 689: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 690: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 691: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 692: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 693: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 694: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 695: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 696: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 697: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 698: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 699: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 700: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 701: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 702: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 703: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 704: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 705: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 706: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 707: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 708: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 709: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 710: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 711: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 712: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 713: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 714: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 715: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 716: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 717: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 718: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 719: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 720: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 721: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 722: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 723: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 724: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 725: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 726: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 727: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 728: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 729: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 730: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 731: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 732: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 733: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 734: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 735: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 736: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 737: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 738: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 739: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 740: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 741: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 742: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 743: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 744: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 745: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 746: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 747: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 748: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 749: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 750: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 751: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 752: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 753: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 754: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 755: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 756: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 757: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 758: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 759: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 760: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 761: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 762: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 763: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 764: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 765: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 766: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 767: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 768: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 769: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 770: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 771: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 772: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 773: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 774: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 775: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 776: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 777: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 778: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 779: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 780: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 781: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 782: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 783: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 784: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 785: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 786: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 787: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 788: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 789: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 790: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 791: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 792: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 793: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 794: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 795: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 796: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 797: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 798: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 799: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 800: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 801: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 802: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 803: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 804: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 805: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 806: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 807: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 808: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 809: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 810: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 811: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 812: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | | %{ bar 813: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 814: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 815: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 816: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 817: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 818: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 819: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
]   \note-mod "5" g''4^.  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 820: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
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
    \new Staff { \new Voice="X" { \time 4/4 r1 | | %{ bar 2: %} d'8 e'16 a''4 r2 r16 | | %{ bar 3: %} g'8  ~ g'4 bes'4 a'4 r8 | | %{ bar 4: %} c'8  ~ c'4 r2 r8 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8  ~ d'4 r2 r8 | | %{ bar 7: %} e'8  ~ e'4 r2 r8 | | %{ bar 8: %} r4 d'8  ~ d'4 r4 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} d'8  ~ d'4 r2 r8 | | %{ bar 11: %} R1 | | %{ bar 12: %} R1 | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'8 c''16 g''4 r2 r16 | | %{ bar 16: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 17: %} c'8  ~ c'4 r2 r8 | | %{ bar 18: %} e'8  ~ e'4 r2 r8 | | %{ bar 19: %} r4 d'8  ~ d'2 r8 | | %{ bar 20: %} R1 | | %{ bar 21: %} R1 | | %{ bar 22: %} d'8 r2. r8 | | %{ bar 23: %} R1 | | %{ bar 24: %} R1 | | %{ bar 25: %} R1 | | %{ bar 26: %} R1 | | %{ bar 27: %} f'8 c''16 g''4 r2 r16 | | %{ bar 28: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 29: %} c'8  ~ c'4 r2 r8 | | %{ bar 30: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 31: %} d'2. r4 | | %{ bar 32: %} R1 | | %{ bar 33: %} d'8 r2. r8 | | %{ bar 34: %} R1 | | %{ bar 35: %} R1 | | %{ bar 36: %} R1 | | %{ bar 37: %} R1 | | %{ bar 38: %} f'8 c''16 g''4 r2 r16 | | %{ bar 39: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 40: %} c'8  ~ c'4 r2 r8 | | %{ bar 41: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 42: %} d'2. r4 | | %{ bar 43: %} R1 | | %{ bar 44: %} d'8 r2. r8 | | %{ bar 45: %} R1 | | %{ bar 46: %} R1 | | %{ bar 47: %} R1 | | %{ bar 48: %} R1 | | %{ bar 49: %} f'8 c''16 g''4 r2 r16 | | %{ bar 50: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 51: %} c'8  ~ c'4 r2 r8 | | %{ bar 52: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 53: %} d'2. r4 | | %{ bar 54: %} R1 | | %{ bar 55: %} d'8 r2. r8 | | %{ bar 56: %} R1 | | %{ bar 57: %} R1 | | %{ bar 58: %} R1 | | %{ bar 59: %} R1 | | %{ bar 60: %} f'8 c''16 g''4 r2 r16 | | %{ bar 61: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 62: %} c'8  ~ c'4 r2 r8 | | %{ bar 63: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 64: %} d'2. r4 | | %{ bar 65: %} R1 | | %{ bar 66: %} d'8 r2. r8 | | %{ bar 67: %} R1 | | %{ bar 68: %} R1 | | %{ bar 69: %} R1 | | %{ bar 70: %} R1 | | %{ bar 71: %} f'8 c''16 g''4 r2 r16 | | %{ bar 72: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 73: %} c'8  ~ c'4 r2 r8 | | %{ bar 74: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 75: %} d'2. r4 | | %{ bar 76: %} R1 | | %{ bar 77: %} d'8 r2. r8 | | %{ bar 78: %} R1 | | %{ bar 79: %} R1 | | %{ bar 80: %} R1 | | %{ bar 81: %} R1 | | %{ bar 82: %} f'8 c''16 g''4 r2 r16 | | %{ bar 83: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 84: %} c'8  ~ c'4 r2 r8 | | %{ bar 85: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 86: %} d'2. r4 | | %{ bar 87: %} R1 | | %{ bar 88: %} d'8 r2. r8 | | %{ bar 89: %} R1 | | %{ bar 90: %} R1 | | %{ bar 91: %} R1 | | %{ bar 92: %} R1 | | %{ bar 93: %} f'8 c''16 g''4 r2 r16 | | %{ bar 94: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 95: %} c'8  ~ c'4 r2 r8 | | %{ bar 96: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 97: %} d'2. r4 | | %{ bar 98: %} R1 | | %{ bar 99: %} d'8 r2. r8 | | %{ bar 100: %} R1 | | %{ bar 101: %} R1 | | %{ bar 102: %} R1 | | %{ bar 103: %} R1 | | %{ bar 104: %} f'8 c''16 g''4 r2 r16 | | %{ bar 105: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 106: %} c'8  ~ c'4 r2 r8 | | %{ bar 107: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 108: %} d'2. r4 | | %{ bar 109: %} R1 | | %{ bar 110: %} d'8 r2. r8 | | %{ bar 111: %} R1 | | %{ bar 112: %} R1 | | %{ bar 113: %} R1 | | %{ bar 114: %} R1 | | %{ bar 115: %} f'8 c''16 g''4 r2 r16 | | %{ bar 116: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 117: %} c'8  ~ c'4 r2 r8 | | %{ bar 118: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 119: %} d'2. r4 | | %{ bar 120: %} R1 | | %{ bar 121: %} d'8 r2. r8 | | %{ bar 122: %} R1 | | %{ bar 123: %} R1 | | %{ bar 124: %} R1 | | %{ bar 125: %} R1 | | %{ bar 126: %} f'8 c''16 g''4 r2 r16 | | %{ bar 127: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 128: %} c'8  ~ c'4 r2 r8 | | %{ bar 129: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 130: %} d'2. r4 | | %{ bar 131: %} R1 | | %{ bar 132: %} d'8 r2. r8 | | %{ bar 133: %} R1 | | %{ bar 134: %} R1 | | %{ bar 135: %} R1 | | %{ bar 136: %} R1 | | %{ bar 137: %} f'8 c''16 g''4 r2 r16 | | %{ bar 138: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 139: %} c'8  ~ c'4 r2 r8 | | %{ bar 140: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 141: %} d'2. r4 | | %{ bar 142: %} R1 | | %{ bar 143: %} d'8 r2. r8 | | %{ bar 144: %} R1 | | %{ bar 145: %} R1 | | %{ bar 146: %} R1 | | %{ bar 147: %} R1 | | %{ bar 148: %} f'8 c''16 g''4 r2 r16 | | %{ bar 149: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 150: %} c'8  ~ c'4 r2 r8 | | %{ bar 151: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 152: %} d'2. r4 | | %{ bar 153: %} R1 | | %{ bar 154: %} d'8 r2. r8 | | %{ bar 155: %} R1 | | %{ bar 156: %} R1 | | %{ bar 157: %} R1 | | %{ bar 158: %} R1 | | %{ bar 159: %} f'8 c''16 g''4 r2 r16 | | %{ bar 160: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 161: %} c'8  ~ c'4 r2 r8 | | %{ bar 162: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 163: %} d'2. r4 | | %{ bar 164: %} R1 | | %{ bar 165: %} d'8 r2. r8 | | %{ bar 166: %} R1 | | %{ bar 167: %} R1 | | %{ bar 168: %} R1 | | %{ bar 169: %} R1 | | %{ bar 170: %} f'8 c''16 g''4 r2 r16 | | %{ bar 171: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 172: %} c'8  ~ c'4 r2 r8 | | %{ bar 173: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 174: %} d'2. r4 | | %{ bar 175: %} R1 | | %{ bar 176: %} d'8 r2. r8 | | %{ bar 177: %} R1 | | %{ bar 178: %} R1 | | %{ bar 179: %} R1 | | %{ bar 180: %} R1 | | %{ bar 181: %} f'8 c''16 g''4 r2 r16 | | %{ bar 182: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 183: %} c'8  ~ c'4 r2 r8 | | %{ bar 184: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 185: %} d'2. r4 | | %{ bar 186: %} R1 | | %{ bar 187: %} d'8 r2. r8 | | %{ bar 188: %} R1 | | %{ bar 189: %} R1 | | %{ bar 190: %} R1 | | %{ bar 191: %} R1 | | %{ bar 192: %} f'8 c''16 g''4 r2 r16 | | %{ bar 193: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 194: %} c'8  ~ c'4 r2 r8 | | %{ bar 195: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 196: %} d'2. r4 | | %{ bar 197: %} R1 | | %{ bar 198: %} d'8 r2. r8 | | %{ bar 199: %} R1 | | %{ bar 200: %} R1 | | %{ bar 201: %} R1 | | %{ bar 202: %} R1 | | %{ bar 203: %} f'8 c''16 g''4 r2 r16 | | %{ bar 204: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 205: %} c'8  ~ c'4 r2 r8 | | %{ bar 206: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 207: %} d'2. r4 | | %{ bar 208: %} R1 | | %{ bar 209: %} d'8 r2. r8 | | %{ bar 210: %} R1 | | %{ bar 211: %} R1 | | %{ bar 212: %} R1 | | %{ bar 213: %} R1 | | %{ bar 214: %} f'8 c''16 g''4 r2 r16 | | %{ bar 215: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 216: %} c'8  ~ c'4 r2 r8 | | %{ bar 217: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 218: %} d'2. r4 | | %{ bar 219: %} R1 | | %{ bar 220: %} d'8 r2. r8 | | %{ bar 221: %} R1 | | %{ bar 222: %} R1 | | %{ bar 223: %} R1 | | %{ bar 224: %} R1 | | %{ bar 225: %} f'8 c''16 g''4 r2 r16 | | %{ bar 226: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 227: %} c'8  ~ c'4 r2 r8 | | %{ bar 228: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 229: %} d'2. r4 | | %{ bar 230: %} R1 | | %{ bar 231: %} d'8 r2. r8 | | %{ bar 232: %} R1 | | %{ bar 233: %} R1 | | %{ bar 234: %} R1 | | %{ bar 235: %} R1 | | %{ bar 236: %} f'8 c''16 g''4 r2 r16 | | %{ bar 237: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 238: %} c'8  ~ c'4 r2 r8 | | %{ bar 239: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 240: %} d'2. r4 | | %{ bar 241: %} R1 | | %{ bar 242: %} d'8 r2. r8 | | %{ bar 243: %} R1 | | %{ bar 244: %} R1 | | %{ bar 245: %} R1 | | %{ bar 246: %} R1 | | %{ bar 247: %} f'8 c''16 g''4 r2 r16 | | %{ bar 248: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 249: %} c'8  ~ c'4 r2 r8 | | %{ bar 250: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 251: %} d'2. r4 | | %{ bar 252: %} R1 | | %{ bar 253: %} d'8 r2. r8 | | %{ bar 254: %} R1 | | %{ bar 255: %} R1 | | %{ bar 256: %} R1 | | %{ bar 257: %} R1 | | %{ bar 258: %} f'8 c''16 g''4 r2 r16 | | %{ bar 259: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 260: %} c'8  ~ c'4 r2 r8 | | %{ bar 261: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 262: %} d'2. r4 | | %{ bar 263: %} R1 | | %{ bar 264: %} d'8 r2. r8 | | %{ bar 265: %} R1 | | %{ bar 266: %} R1 | | %{ bar 267: %} R1 | | %{ bar 268: %} R1 | | %{ bar 269: %} f'8 c''16 g''4 r2 r16 | | %{ bar 270: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 271: %} c'8  ~ c'4 r2 r8 | | %{ bar 272: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 273: %} d'2. r4 | | %{ bar 274: %} R1 | | %{ bar 275: %} d'8 r2. r8 | | %{ bar 276: %} R1 | | %{ bar 277: %} R1 | | %{ bar 278: %} R1 | | %{ bar 279: %} R1 | | %{ bar 280: %} f'8 c''16 g''4 r2 r16 | | %{ bar 281: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 282: %} c'8  ~ c'4 r2 r8 | | %{ bar 283: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 284: %} d'2. r4 | | %{ bar 285: %} R1 | | %{ bar 286: %} d'8 r2. r8 | | %{ bar 287: %} R1 | | %{ bar 288: %} R1 | | %{ bar 289: %} R1 | | %{ bar 290: %} R1 | | %{ bar 291: %} f'8 c''16 g''4 r2 r16 | | %{ bar 292: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 293: %} c'8  ~ c'4 r2 r8 | | %{ bar 294: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 295: %} d'2. r4 | | %{ bar 296: %} R1 | | %{ bar 297: %} d'8 r2. r8 | | %{ bar 298: %} R1 | | %{ bar 299: %} R1 | | %{ bar 300: %} R1 | | %{ bar 301: %} R1 | | %{ bar 302: %} f'8 c''16 g''4 r2 r16 | | %{ bar 303: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 304: %} c'8  ~ c'4 r2 r8 | | %{ bar 305: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 306: %} d'2. r4 | | %{ bar 307: %} R1 | | %{ bar 308: %} d'8 r2. r8 | | %{ bar 309: %} R1 | | %{ bar 310: %} R1 | | %{ bar 311: %} R1 | | %{ bar 312: %} R1 | | %{ bar 313: %} f'8 c''16 g''4 r2 r16 | | %{ bar 314: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 315: %} c'8  ~ c'4 r2 r8 | | %{ bar 316: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 317: %} d'2. r4 | | %{ bar 318: %} R1 | | %{ bar 319: %} d'8 r2. r8 | | %{ bar 320: %} R1 | | %{ bar 321: %} R1 | | %{ bar 322: %} R1 | | %{ bar 323: %} R1 | | %{ bar 324: %} f'8 c''16 g''4 r2 r16 | | %{ bar 325: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 326: %} c'8  ~ c'4 r2 r8 | | %{ bar 327: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 328: %} d'2. r4 | | %{ bar 329: %} R1 | | %{ bar 330: %} d'8 r2. r8 | | %{ bar 331: %} R1 | | %{ bar 332: %} R1 | | %{ bar 333: %} R1 | | %{ bar 334: %} R1 | | %{ bar 335: %} f'8 c''16 g''4 r2 r16 | | %{ bar 336: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 337: %} c'8  ~ c'4 r2 r8 | | %{ bar 338: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 339: %} d'2. r4 | | %{ bar 340: %} R1 | | %{ bar 341: %} d'8 r2. r8 | | %{ bar 342: %} R1 | | %{ bar 343: %} R1 | | %{ bar 344: %} R1 | | %{ bar 345: %} R1 | | %{ bar 346: %} f'8 c''16 g''4 r2 r16 | | %{ bar 347: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 348: %} c'8  ~ c'4 r2 r8 | | %{ bar 349: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 350: %} d'2. r4 | | %{ bar 351: %} R1 | | %{ bar 352: %} d'8 r2. r8 | | %{ bar 353: %} R1 | | %{ bar 354: %} R1 | | %{ bar 355: %} R1 | | %{ bar 356: %} R1 | | %{ bar 357: %} f'8 c''16 g''4 r2 r16 | | %{ bar 358: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 359: %} c'8  ~ c'4 r2 r8 | | %{ bar 360: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 361: %} d'2. r4 | | %{ bar 362: %} R1 | | %{ bar 363: %} d'8 r2. r8 | | %{ bar 364: %} R1 | | %{ bar 365: %} R1 | | %{ bar 366: %} R1 | | %{ bar 367: %} R1 | | %{ bar 368: %} f'8 c''16 g''4 r2 r16 | | %{ bar 369: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 370: %} c'8  ~ c'4 r2 r8 | | %{ bar 371: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 372: %} d'2. r4 | | %{ bar 373: %} R1 | | %{ bar 374: %} d'8 r2. r8 | | %{ bar 375: %} R1 | | %{ bar 376: %} R1 | | %{ bar 377: %} R1 | | %{ bar 378: %} R1 | | %{ bar 379: %} f'8 c''16 g''4 r2 r16 | | %{ bar 380: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 381: %} c'8  ~ c'4 r2 r8 | | %{ bar 382: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 383: %} d'2. r4 | | %{ bar 384: %} R1 | | %{ bar 385: %} d'8 r2. r8 | | %{ bar 386: %} R1 | | %{ bar 387: %} R1 | | %{ bar 388: %} R1 | | %{ bar 389: %} R1 | | %{ bar 390: %} f'8 c''16 g''4 r2 r16 | | %{ bar 391: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 392: %} c'8  ~ c'4 r2 r8 | | %{ bar 393: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 394: %} d'2. r4 | | %{ bar 395: %} R1 | | %{ bar 396: %} d'8 r2. r8 | | %{ bar 397: %} R1 | | %{ bar 398: %} R1 | | %{ bar 399: %} R1 | | %{ bar 400: %} R1 | | %{ bar 401: %} f'8 c''16 g''4 r2 r16 | | %{ bar 402: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 403: %} c'8  ~ c'4 r2 r8 | | %{ bar 404: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 405: %} d'2. r4 | | %{ bar 406: %} R1 | | %{ bar 407: %} d'8 r2. r8 | | %{ bar 408: %} R1 | | %{ bar 409: %} R1 | | %{ bar 410: %} R1 | | %{ bar 411: %} R1 | | %{ bar 412: %} f'8 c''16 g''4 r2 r16 | | %{ bar 413: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 414: %} c'8  ~ c'4 r2 r8 | | %{ bar 415: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 416: %} d'2. r4 | | %{ bar 417: %} R1 | | %{ bar 418: %} d'8 r2. r8 | | %{ bar 419: %} R1 | | %{ bar 420: %} R1 | | %{ bar 421: %} R1 | | %{ bar 422: %} R1 | | %{ bar 423: %} f'8 c''16 g''4 r2 r16 | | %{ bar 424: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 425: %} c'8  ~ c'4 r2 r8 | | %{ bar 426: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 427: %} d'2. r4 | | %{ bar 428: %} R1 | | %{ bar 429: %} d'8 r2. r8 | | %{ bar 430: %} R1 | | %{ bar 431: %} R1 | | %{ bar 432: %} R1 | | %{ bar 433: %} R1 | | %{ bar 434: %} f'8 c''16 g''4 r2 r16 | | %{ bar 435: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 436: %} c'8  ~ c'4 r2 r8 | | %{ bar 437: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 438: %} d'2. r4 | | %{ bar 439: %} R1 | | %{ bar 440: %} d'8 r2. r8 | | %{ bar 441: %} R1 | | %{ bar 442: %} R1 | | %{ bar 443: %} R1 | | %{ bar 444: %} R1 | | %{ bar 445: %} f'8 c''16 g''4 r2 r16 | | %{ bar 446: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 447: %} c'8  ~ c'4 r2 r8 | | %{ bar 448: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 449: %} d'2. r4 | | %{ bar 450: %} R1 | | %{ bar 451: %} d'8 r2. r8 | | %{ bar 452: %} R1 | | %{ bar 453: %} R1 | | %{ bar 454: %} R1 | | %{ bar 455: %} R1 | | %{ bar 456: %} f'8 c''16 g''4 r2 r16 | | %{ bar 457: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 458: %} c'8  ~ c'4 r2 r8 | | %{ bar 459: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 460: %} d'2. r4 | | %{ bar 461: %} R1 | | %{ bar 462: %} d'8 r2. r8 | | %{ bar 463: %} R1 | | %{ bar 464: %} R1 | | %{ bar 465: %} R1 | | %{ bar 466: %} R1 | | %{ bar 467: %} f'8 c''16 g''4 r2 r16 | | %{ bar 468: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 469: %} c'8  ~ c'4 r2 r8 | | %{ bar 470: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 471: %} d'2. r4 | | %{ bar 472: %} R1 | | %{ bar 473: %} d'8 r2. r8 | | %{ bar 474: %} R1 | | %{ bar 475: %} R1 | | %{ bar 476: %} R1 | | %{ bar 477: %} R1 | | %{ bar 478: %} f'8 c''16 g''4 r2 r16 | | %{ bar 479: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 480: %} c'8  ~ c'4 r2 r8 | | %{ bar 481: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 482: %} d'2. r4 | | %{ bar 483: %} R1 | | %{ bar 484: %} d'8 r2. r8 | | %{ bar 485: %} R1 | | %{ bar 486: %} R1 | | %{ bar 487: %} R1 | | %{ bar 488: %} R1 | | %{ bar 489: %} f'8 c''16 g''4 r2 r16 | | %{ bar 490: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 491: %} c'8  ~ c'4 r2 r8 | | %{ bar 492: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 493: %} d'2. r4 | | %{ bar 494: %} R1 | | %{ bar 495: %} d'8 r2. r8 | | %{ bar 496: %} R1 | | %{ bar 497: %} R1 | | %{ bar 498: %} R1 | | %{ bar 499: %} R1 | | %{ bar 500: %} f'8 c''16 g''4 r2 r16 | | %{ bar 501: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 502: %} c'8  ~ c'4 r2 r8 | | %{ bar 503: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 504: %} d'2. r4 | | %{ bar 505: %} R1 | | %{ bar 506: %} d'8 r2. r8 | | %{ bar 507: %} R1 | | %{ bar 508: %} R1 | | %{ bar 509: %} R1 | | %{ bar 510: %} R1 | | %{ bar 511: %} f'8 c''16 g''4 r2 r16 | | %{ bar 512: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 513: %} c'8  ~ c'4 r2 r8 | | %{ bar 514: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 515: %} d'2. r4 | | %{ bar 516: %} R1 | | %{ bar 517: %} d'8 r2. r8 | | %{ bar 518: %} R1 | | %{ bar 519: %} R1 | | %{ bar 520: %} R1 | | %{ bar 521: %} R1 | | %{ bar 522: %} f'8 c''16 g''4 r2 r16 | | %{ bar 523: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 524: %} c'8  ~ c'4 r2 r8 | | %{ bar 525: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 526: %} d'2. r4 | | %{ bar 527: %} R1 | | %{ bar 528: %} d'8 r2. r8 | | %{ bar 529: %} R1 | | %{ bar 530: %} R1 | | %{ bar 531: %} R1 | | %{ bar 532: %} R1 | | %{ bar 533: %} f'8 c''16 g''4 r2 r16 | | %{ bar 534: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 535: %} c'8  ~ c'4 r2 r8 | | %{ bar 536: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 537: %} d'2. r4 | | %{ bar 538: %} R1 | | %{ bar 539: %} d'8 r2. r8 | | %{ bar 540: %} R1 | | %{ bar 541: %} R1 | | %{ bar 542: %} R1 | | %{ bar 543: %} R1 | | %{ bar 544: %} f'8 c''16 g''4 r2 r16 | | %{ bar 545: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 546: %} c'8  ~ c'4 r2 r8 | | %{ bar 547: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 548: %} d'2. r4 | | %{ bar 549: %} R1 | | %{ bar 550: %} d'8 r2. r8 | | %{ bar 551: %} R1 | | %{ bar 552: %} R1 | | %{ bar 553: %} R1 | | %{ bar 554: %} R1 | | %{ bar 555: %} f'8 c''16 g''4 r2 r16 | | %{ bar 556: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 557: %} c'8  ~ c'4 r2 r8 | | %{ bar 558: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 559: %} d'2. r4 | | %{ bar 560: %} R1 | | %{ bar 561: %} d'8 r2. r8 | | %{ bar 562: %} R1 | | %{ bar 563: %} R1 | | %{ bar 564: %} R1 | | %{ bar 565: %} R1 | | %{ bar 566: %} f'8 c''16 g''4 r2 r16 | | %{ bar 567: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 568: %} c'8  ~ c'4 r2 r8 | | %{ bar 569: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 570: %} d'2. r4 | | %{ bar 571: %} R1 | | %{ bar 572: %} d'8 r2. r8 | | %{ bar 573: %} R1 | | %{ bar 574: %} R1 | | %{ bar 575: %} R1 | | %{ bar 576: %} R1 | | %{ bar 577: %} f'8 c''16 g''4 r2 r16 | | %{ bar 578: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 579: %} c'8  ~ c'4 r2 r8 | | %{ bar 580: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 581: %} d'2. r4 | | %{ bar 582: %} R1 | | %{ bar 583: %} d'8 r2. r8 | | %{ bar 584: %} R1 | | %{ bar 585: %} R1 | | %{ bar 586: %} R1 | | %{ bar 587: %} R1 | | %{ bar 588: %} f'8 c''16 g''4 r2 r16 | | %{ bar 589: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 590: %} c'8  ~ c'4 r2 r8 | | %{ bar 591: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 592: %} d'2. r4 | | %{ bar 593: %} R1 | | %{ bar 594: %} d'8 r2. r8 | | %{ bar 595: %} R1 | | %{ bar 596: %} R1 | | %{ bar 597: %} R1 | | %{ bar 598: %} R1 | | %{ bar 599: %} f'8 c''16 g''4 r2 r16 | | %{ bar 600: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 601: %} c'8  ~ c'4 r2 r8 | | %{ bar 602: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 603: %} d'2. r4 | | %{ bar 604: %} R1 | | %{ bar 605: %} d'8 r2. r8 | | %{ bar 606: %} R1 | | %{ bar 607: %} R1 | | %{ bar 608: %} R1 | | %{ bar 609: %} R1 | | %{ bar 610: %} f'8 c''16 g''4 r2 r16 | | %{ bar 611: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 612: %} c'8  ~ c'4 r2 r8 | | %{ bar 613: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 614: %} d'2. r4 | | %{ bar 615: %} R1 | | %{ bar 616: %} d'8 r2. r8 | | %{ bar 617: %} R1 | | %{ bar 618: %} R1 | | %{ bar 619: %} R1 | | %{ bar 620: %} R1 | | %{ bar 621: %} f'8 c''16 g''4 r2 r16 | | %{ bar 622: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 623: %} c'8  ~ c'4 r2 r8 | | %{ bar 624: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 625: %} d'2. r4 | | %{ bar 626: %} R1 | | %{ bar 627: %} d'8 r2. r8 | | %{ bar 628: %} R1 | | %{ bar 629: %} R1 | | %{ bar 630: %} R1 | | %{ bar 631: %} R1 | | %{ bar 632: %} f'8 c''16 g''4 r2 r16 | | %{ bar 633: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 634: %} c'8  ~ c'4 r2 r8 | | %{ bar 635: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 636: %} d'2. r4 | | %{ bar 637: %} R1 | | %{ bar 638: %} d'8 r2. r8 | | %{ bar 639: %} R1 | | %{ bar 640: %} R1 | | %{ bar 641: %} R1 | | %{ bar 642: %} R1 | | %{ bar 643: %} f'8 c''16 g''4 r2 r16 | | %{ bar 644: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 645: %} c'8  ~ c'4 r2 r8 | | %{ bar 646: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 647: %} d'2. r4 | | %{ bar 648: %} R1 | | %{ bar 649: %} d'8 r2. r8 | | %{ bar 650: %} R1 | | %{ bar 651: %} R1 | | %{ bar 652: %} R1 | | %{ bar 653: %} R1 | | %{ bar 654: %} f'8 c''16 g''4 r2 r16 | | %{ bar 655: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 656: %} c'8  ~ c'4 r2 r8 | | %{ bar 657: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 658: %} d'2. r4 | | %{ bar 659: %} R1 | | %{ bar 660: %} d'8 r2. r8 | | %{ bar 661: %} R1 | | %{ bar 662: %} R1 | | %{ bar 663: %} R1 | | %{ bar 664: %} R1 | | %{ bar 665: %} f'8 c''16 g''4 r2 r16 | | %{ bar 666: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 667: %} c'8  ~ c'4 r2 r8 | | %{ bar 668: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 669: %} d'2. r4 | | %{ bar 670: %} R1 | | %{ bar 671: %} d'8 r2. r8 | | %{ bar 672: %} R1 | | %{ bar 673: %} R1 | | %{ bar 674: %} R1 | | %{ bar 675: %} R1 | | %{ bar 676: %} f'8 c''16 g''4 r2 r16 | | %{ bar 677: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 678: %} c'8  ~ c'4 r2 r8 | | %{ bar 679: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 680: %} d'2. r4 | | %{ bar 681: %} R1 | | %{ bar 682: %} d'8 r2. r8 | | %{ bar 683: %} R1 | | %{ bar 684: %} R1 | | %{ bar 685: %} R1 | | %{ bar 686: %} R1 | | %{ bar 687: %} f'8 c''16 g''4 r2 r16 | | %{ bar 688: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 689: %} c'8  ~ c'4 r2 r8 | | %{ bar 690: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 691: %} d'2. r4 | | %{ bar 692: %} R1 | | %{ bar 693: %} d'8 r2. r8 | | %{ bar 694: %} R1 | | %{ bar 695: %} R1 | | %{ bar 696: %} R1 | | %{ bar 697: %} R1 | | %{ bar 698: %} f'8 c''16 g''4 r2 r16 | | %{ bar 699: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 700: %} c'8  ~ c'4 r2 r8 | | %{ bar 701: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 702: %} d'2. r4 | | %{ bar 703: %} R1 | | %{ bar 704: %} d'8 r2. r8 | | %{ bar 705: %} R1 | | %{ bar 706: %} R1 | | %{ bar 707: %} R1 | | %{ bar 708: %} R1 | | %{ bar 709: %} f'8 c''16 g''4 r2 r16 | | %{ bar 710: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 711: %} c'8  ~ c'4 r2 r8 | | %{ bar 712: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 713: %} d'2. r4 | | %{ bar 714: %} R1 | | %{ bar 715: %} d'8 r2. r8 | | %{ bar 716: %} R1 | | %{ bar 717: %} R1 | | %{ bar 718: %} R1 | | %{ bar 719: %} R1 | | %{ bar 720: %} f'8 c''16 g''4 r2 r16 | | %{ bar 721: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 722: %} c'8  ~ c'4 r2 r8 | | %{ bar 723: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 724: %} d'2. r4 | | %{ bar 725: %} R1 | | %{ bar 726: %} d'8 r2. r8 | | %{ bar 727: %} R1 | | %{ bar 728: %} R1 | | %{ bar 729: %} R1 | | %{ bar 730: %} R1 | | %{ bar 731: %} f'8 c''16 g''4 r2 r16 | | %{ bar 732: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 733: %} c'8  ~ c'4 r2 r8 | | %{ bar 734: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 735: %} d'2. r4 | | %{ bar 736: %} R1 | | %{ bar 737: %} d'8 r2. r8 | | %{ bar 738: %} R1 | | %{ bar 739: %} R1 | | %{ bar 740: %} R1 | | %{ bar 741: %} R1 | | %{ bar 742: %} f'8 c''16 g''4 r2 r16 | | %{ bar 743: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 744: %} c'8  ~ c'4 r2 r8 | | %{ bar 745: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 746: %} d'2. r4 | | %{ bar 747: %} R1 | | %{ bar 748: %} d'8 r2. r8 | | %{ bar 749: %} R1 | | %{ bar 750: %} R1 | | %{ bar 751: %} R1 | | %{ bar 752: %} R1 | | %{ bar 753: %} f'8 c''16 g''4 r2 r16 | | %{ bar 754: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 755: %} c'8  ~ c'4 r2 r8 | | %{ bar 756: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 757: %} d'2. r4 | | %{ bar 758: %} R1 | | %{ bar 759: %} d'8 r2. r8 | | %{ bar 760: %} R1 | | %{ bar 761: %} R1 | | %{ bar 762: %} R1 | | %{ bar 763: %} R1 | | %{ bar 764: %} f'8 c''16 g''4 r2 r16 | | %{ bar 765: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 766: %} c'8  ~ c'4 r2 r8 | | %{ bar 767: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 768: %} d'2. r4 | | %{ bar 769: %} R1 | | %{ bar 770: %} d'8 r2. r8 | | %{ bar 771: %} R1 | | %{ bar 772: %} R1 | | %{ bar 773: %} R1 | | %{ bar 774: %} R1 | | %{ bar 775: %} f'8 c''16 g''4 r2 r16 | | %{ bar 776: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 777: %} c'8  ~ c'4 r2 r8 | | %{ bar 778: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 779: %} d'2. r4 | | %{ bar 780: %} R1 | | %{ bar 781: %} d'8 r2. r8 | | %{ bar 782: %} R1 | | %{ bar 783: %} R1 | | %{ bar 784: %} R1 | | %{ bar 785: %} R1 | | %{ bar 786: %} f'8 c''16 g''4 r2 r16 | | %{ bar 787: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 788: %} c'8  ~ c'4 r2 r8 | | %{ bar 789: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 790: %} d'2. r4 | | %{ bar 791: %} R1 | | %{ bar 792: %} d'8 r2. r8 | | %{ bar 793: %} R1 | | %{ bar 794: %} R1 | | %{ bar 795: %} R1 | | %{ bar 796: %} R1 | | %{ bar 797: %} f'8 c''16 g''4 r2 r16 | | %{ bar 798: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 799: %} c'8  ~ c'4 r2 r8 | | %{ bar 800: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 801: %} d'2. r4 | | %{ bar 802: %} R1 | | %{ bar 803: %} d'8 r2. r8 | | %{ bar 804: %} R1 | | %{ bar 805: %} R1 | | %{ bar 806: %} R1 | | %{ bar 807: %} R1 | | %{ bar 808: %} f'8 c''16 g''4 r2 r16 | | %{ bar 809: %} bes'4 a'4 g'8  ~ g'4 r8 | | %{ bar 810: %} c'8  ~ c'4 r2 r8 | | %{ bar 811: %} e'8  ~ e'2 d'8  ~ d'4  ~ | | %{ bar 812: %} d'2. r4 | | %{ bar 813: %} R1 | | %{ bar 814: %} d'8 r2. r8 | | %{ bar 815: %} R1 | | %{ bar 816: %} R1 | | %{ bar 817: %} R1 | | %{ bar 818: %} R1 | | %{ bar 819: %} f'8 c''16 g''4 r2 r16 | | %{ bar 820: %} bes'4 a'4 r2 | } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
