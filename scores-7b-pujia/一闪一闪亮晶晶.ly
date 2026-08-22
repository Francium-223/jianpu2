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
1 0 0 0
0 0 0 0 | q2 0 0 0 q0 | s3 0 0 0 q0. | d0 - 0 0 q0. d0 | q6 0 0 0 q0 | q5 0 0 0 q0 | - q7 - q1' 0 | 0 0 0 0 |
0 0 0 0 | q1 - s1 - d1 0 d0 | 1 - 1 - | 1 - 1 - | d1 - 1 - q0. d0 | b1 - 1 - | 1 - 1 - | 1 - d1 - q0. d0 | 1 - b1 - | 1 - 1 - | 1 - 1 - | d1 - 1 - q0. d0 | b1 - 1 - | 0 0 0 0 |
2 0 0 0
0 0 0 0 | s3 0 0 0 q0. | d0 - q7 0 0 s0. | 0 0 0 0 |
0 0 0 0 | q6 - s5 - q4 q0. | - s3 - d2 - d2 q0 | - s2 - 2 q0. | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
2' 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 - 2 q0 d0 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - 2 - 2 | - d2 - b2 q0. d0 | - b2 - 2 | - 1' 0 0 | 0 0 0 0 |
1 0 0 0
0 0 0 0 | q6 0 0 0 q0 | s5 - q4 - s3 - | d2 - s2 0 0 q0 d0 |
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
     \time 4/4  \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "0" c'32[
]   \note-mod "–" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[]
 \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c'16[
]  ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "1" c'32[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "0" c'32[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 12: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 13: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "1" c'32[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 15: %}
 \note-mod "1" \once \tweak Accidental.extra-offset #'(0 . 0.7)ces'4
 ~  \note-mod "–" ces'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" \once \tweak Accidental.extra-offset #'(0 . 0.7)c'4
 ~  \note-mod "–" c'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 16: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 17: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "1" c'32[
]  ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 18: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" \once \tweak Accidental.extra-offset #'(0 . 0.7)ces'4
 ~  \note-mod "–" ces'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 19: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 20: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 21: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "1" c'32[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 22: %}
 \note-mod "1" \once \tweak Accidental.extra-offset #'(0 . 0.7)ces'4
 ~  \note-mod "–" ces'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" \once \tweak Accidental.extra-offset #'(0 . 0.7)c'4
 ~  \note-mod "–" c'4 | | %{ bar 23: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 24: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 25: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 26: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 27: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "0" c'32[
]   \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16.[]
| | %{ bar 28: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 29: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  ~  \note-mod "–" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8.]
| | %{ bar 31: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[
]  ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 32: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[]
| | %{ bar 33: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 34: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 35: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 36: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 37: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 38: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 39: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 40: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 41: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 42: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 43: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 44: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 45: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 46: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 47: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 48: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 49: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 50: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 51: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 52: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 53: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 54: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 55: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 56: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 57: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 58: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 59: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 60: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 61: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 62: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 63: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 64: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 65: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 66: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 67: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 68: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 69: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 70: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 71: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 72: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 73: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 74: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 75: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 76: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 77: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 78: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 79: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 80: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 81: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 82: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 83: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 84: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 85: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 86: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 87: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 88: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 89: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 90: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 91: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 92: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 93: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 94: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 95: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 96: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 97: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 98: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 99: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 100: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 101: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 102: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 103: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 104: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 105: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 106: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 107: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 108: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 109: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 111: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 112: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 113: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 114: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 115: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 116: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 117: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 118: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 119: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 120: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 121: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 122: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 123: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 124: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 125: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 126: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 127: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 128: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 129: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 130: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 131: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 132: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 133: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 134: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 135: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 136: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 137: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 138: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 139: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 140: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 141: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 142: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 143: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 144: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 145: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 146: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 147: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 148: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 149: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 150: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 151: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 152: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 153: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 154: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 155: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 156: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 157: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 158: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 159: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 160: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 161: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 162: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 163: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 164: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 165: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 166: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 167: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 168: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 169: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 170: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 171: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 172: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 173: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 174: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 175: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 176: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 177: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 178: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 179: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 180: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 181: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 182: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 183: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 184: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 185: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 186: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 187: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 188: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 189: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 190: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 191: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 192: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 193: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 194: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 195: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 196: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 197: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 198: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 199: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 200: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 201: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 202: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 203: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 204: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 205: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 206: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 207: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 208: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 209: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 210: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 211: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 212: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 213: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 214: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 215: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 216: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 217: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 218: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 219: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 220: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 221: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 222: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 223: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 224: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 225: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 226: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 227: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 228: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 229: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 230: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 231: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 232: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 233: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 234: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 235: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 236: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 237: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 238: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 239: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 240: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 241: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 242: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 243: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 244: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 245: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 246: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 247: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 248: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 249: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 250: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 251: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 252: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 253: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 254: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 255: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 256: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 257: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 258: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 259: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 260: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 261: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 262: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 263: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 264: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 265: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 266: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 267: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 268: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 269: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 270: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 271: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 272: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 273: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 274: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 275: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 276: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 277: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 278: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 279: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 280: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 281: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 282: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 283: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 284: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 285: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 286: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 287: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 288: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 289: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 290: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 291: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 292: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 293: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 294: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 295: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 296: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 297: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 298: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 299: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 300: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 301: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 302: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 303: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 304: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 305: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 306: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 307: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 308: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 309: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 310: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 311: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 312: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 313: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 314: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 315: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 316: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 317: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 318: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 319: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 320: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 321: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 322: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 323: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 324: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 325: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 326: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 327: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 328: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 329: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 330: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 331: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 332: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 333: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 334: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 335: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 336: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 337: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 338: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 339: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 340: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 341: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 342: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 343: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 344: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 345: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 346: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 347: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 348: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 349: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 350: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 351: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 352: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 353: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 354: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 355: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 356: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 357: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 358: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 359: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 360: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 361: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 362: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 363: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 364: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 365: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 366: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 367: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 368: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 369: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 370: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 371: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 372: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 373: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 374: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 375: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 376: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 377: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 378: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 379: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 380: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 381: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 382: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 383: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 384: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 385: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 386: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 387: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 388: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 389: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 390: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 391: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 392: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 393: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 394: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 395: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 396: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 397: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 398: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 399: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 400: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 401: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 402: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 403: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 404: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 405: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 406: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 407: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 408: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 409: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 410: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 411: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 412: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 413: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 414: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 415: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 416: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 417: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 418: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 419: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 420: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 421: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 422: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 423: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 424: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 425: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 426: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 427: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 428: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 429: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 430: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 431: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 432: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 433: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 434: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 435: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 436: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 437: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 438: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 439: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 440: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 441: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 442: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 443: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 444: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 445: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 446: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 447: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 448: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 449: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 450: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 451: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 452: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 453: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 454: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 455: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 456: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 457: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 458: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 459: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 460: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 461: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 462: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 463: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 464: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 465: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 466: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 467: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 468: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 469: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 470: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 471: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 472: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 473: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 474: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 475: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 476: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 477: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 478: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 479: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 480: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 481: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 482: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 483: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 484: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 485: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 486: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 487: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 488: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 489: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 490: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 491: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 492: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 493: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 494: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 495: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 496: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 497: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 498: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 499: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 500: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 501: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 502: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 503: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 504: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 505: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 506: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 507: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 508: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 509: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 510: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 511: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 512: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 513: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 514: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 515: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 516: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 517: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 518: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 519: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 520: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 521: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 522: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 523: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 524: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 525: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 526: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 527: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 528: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 529: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 530: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 531: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 532: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 533: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 534: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 535: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 536: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 537: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 538: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 539: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 540: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 541: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 542: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 543: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 544: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 545: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 546: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 547: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 548: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 549: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 550: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 551: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 552: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 553: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 554: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 555: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 556: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 557: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 558: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 559: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 560: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 561: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 562: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 563: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 564: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 565: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 566: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 567: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 568: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 569: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 570: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 571: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 572: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 573: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 574: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 575: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 576: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 577: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 578: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 579: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 580: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 581: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 582: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 583: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 584: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 585: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 586: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 587: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 588: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 589: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 590: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 591: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 592: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 593: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 594: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 595: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 596: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 597: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 598: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 599: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 600: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 601: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 602: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 603: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 604: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 605: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 606: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 607: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 608: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 609: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 610: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 611: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 612: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 613: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 614: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 615: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 616: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 617: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 618: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 619: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 620: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 621: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 622: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 623: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 624: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 625: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 626: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 627: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 628: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 629: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 630: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 631: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 632: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 633: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 634: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 635: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 636: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 637: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 638: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 639: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 640: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 641: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 642: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 643: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 644: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 645: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 646: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 647: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 648: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 649: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 650: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 651: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 652: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 653: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 654: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 655: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 656: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 657: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 658: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 659: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 660: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 661: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 662: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 663: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 664: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 665: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 666: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 667: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 668: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 669: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 670: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 671: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 672: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 673: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 674: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 675: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 676: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 677: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 678: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 679: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 680: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 681: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 682: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 683: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 684: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 685: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 686: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 687: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 688: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 689: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 690: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 691: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 692: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 693: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 694: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 695: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 696: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 697: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 698: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 699: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 700: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 701: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 702: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 703: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 704: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 705: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 706: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 707: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 708: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 709: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 710: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 711: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 712: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 713: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 714: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 715: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 716: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 717: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 718: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 719: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 720: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 721: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 722: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 723: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 724: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 725: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 726: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 727: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 728: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 729: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 730: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 731: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 732: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 733: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 734: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 735: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 736: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 737: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 738: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 739: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 740: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 741: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 742: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 743: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 744: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 745: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 746: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 747: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 748: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 749: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 750: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 751: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 752: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 753: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 754: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 755: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 756: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 757: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 758: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 759: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 760: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 761: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 762: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 763: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 764: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 765: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 766: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 767: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 768: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 769: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 770: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 771: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 772: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 773: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 774: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 775: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 776: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 777: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 778: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 779: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 780: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 781: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 782: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 783: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 784: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 785: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 786: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 787: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 788: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 789: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 790: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 791: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 792: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 793: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 794: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 795: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 796: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 797: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 798: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 799: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 800: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 801: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 802: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 803: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 804: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 805: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 806: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 807: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 808: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 809: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 810: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 811: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 812: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 813: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 814: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 815: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 816: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 817: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 818: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 819: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 820: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 821: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 822: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 823: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 824: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 825: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 826: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 827: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 828: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 829: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 830: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 831: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 832: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 833: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 834: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 835: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 836: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 837: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 838: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 839: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 840: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 841: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 842: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 843: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 844: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 845: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 846: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 847: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 848: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 849: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 850: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 851: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 852: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 853: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 854: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 855: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 856: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 857: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 858: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 859: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 860: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 861: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 862: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 863: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 864: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 865: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 866: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 867: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 868: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 869: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 870: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 871: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 872: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 873: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 874: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 875: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 876: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 877: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 878: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 879: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 880: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 881: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 882: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 883: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 884: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 885: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 886: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 887: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 888: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 889: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 890: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 891: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 892: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 893: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 894: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 895: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 896: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 897: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 898: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 899: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 900: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 901: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 902: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 903: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 904: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 905: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 906: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 907: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 908: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 909: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 910: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 911: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 912: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 913: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 914: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 915: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 916: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 917: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 918: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 919: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 920: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 921: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 922: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 923: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 924: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 925: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 926: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 927: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 928: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]  ~  \note-mod "–" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 929: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 930: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 931: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 932: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 933: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 934: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 935: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ | | %{ bar 936: %}
 \note-mod "2" d'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| | %{ bar 937: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des'4
 ~  \note-mod "–" des'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)d'4
\=JianpuTie(  ~ | | %{ bar 938: %}
 \note-mod "2" d'4 \=JianpuTie)
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 939: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 940: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 941: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 942: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 943: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[]
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 944: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #3
 \note-mod "2" d'32[
]  ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
 \note-mod "0" r32]
| \bar "|." } }
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
    \new Staff { \new Voice="X" { \time 4/4 c'4 r2. | %{ bar 2: %} R1 | | %{ bar 3: %} d'8 r2. r8 | | %{ bar 4: %} e'16 r2. r8. | | %{ bar 5: %} r32 r2. r8. r32 | | %{ bar 6: %} a'8 r2. r8 | | %{ bar 7: %} g'8 r2. r8 | | %{ bar 8: %} r4 b'8  ~ b'4 c''8 r4 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8  ~ c'4 c'16  ~ c'4 c'32 r4 r32 | | %{ bar 12: %} c'2 c'2 | | %{ bar 13: %} c'2 c'2 | | %{ bar 14: %} c'32  ~ c'4 c'2 r8. r32 | | %{ bar 15: %} ces'2 c'2 | | %{ bar 16: %} c'2 c'2 | | %{ bar 17: %} c'2 c'32  ~ c'4 r8. r32 | | %{ bar 18: %} c'2 ces'2 | | %{ bar 19: %} c'2 c'2 | | %{ bar 20: %} c'2 c'2 | | %{ bar 21: %} c'32  ~ c'4 c'2 r8. r32 | | %{ bar 22: %} ces'2 c'2 | | %{ bar 23: %} R1 | | %{ bar 24: %} d'4 r2. | %{ bar 25: %} R1 | | %{ bar 26: %} e'16 r2. r8. | | %{ bar 27: %} r32 r4 b'8 r2 r16. | | %{ bar 28: %} R1 | | %{ bar 29: %} R1 | | %{ bar 30: %} a'8  ~ a'4 g'16  ~ g'4 f'8 r8. | | %{ bar 31: %} r4 e'16  ~ e'4 d'32  ~ d'4 d'32 r8 | | %{ bar 32: %} r4 d'16  ~ d'4 d'4 r8. | | %{ bar 33: %} r4 d'2 d'4  ~ | | %{ bar 34: %} d'4 d'2 d'4  ~ | | %{ bar 35: %} d'4 d'2 d'4  ~ | | %{ bar 36: %} d'4 d'2 d'4  ~ | | %{ bar 37: %} d'4 d'2 d'4  ~ | | %{ bar 38: %} d'4 d'2 d'4  ~ | | %{ bar 39: %} d'4 d'2 d'4  ~ | | %{ bar 40: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 41: %} r4 des'2 d'4  ~ | | %{ bar 42: %} d'4 c''4 r2 | | %{ bar 43: %} R1 | | %{ bar 44: %} d''4 r2. | %{ bar 45: %} R1 | | %{ bar 46: %} a'8 r2. r8 | | %{ bar 47: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 48: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 49: %} r4 d'2 d'4  ~ | | %{ bar 50: %} d'4 d'2 d'4  ~ | | %{ bar 51: %} d'4 d'2 d'4  ~ | | %{ bar 52: %} d'4 d'2 d'4  ~ | | %{ bar 53: %} d'4 d'2 d'4  ~ | | %{ bar 54: %} d'4 d'2 d'4  ~ | | %{ bar 55: %} d'4 d'2 d'4  ~ | | %{ bar 56: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 57: %} r4 des'2 d'4  ~ | | %{ bar 58: %} d'4 c''4 r2 | | %{ bar 59: %} R1 | | %{ bar 60: %} c'4 r2. | %{ bar 61: %} R1 | | %{ bar 62: %} a'8 r2. r8 | | %{ bar 63: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 64: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 65: %} r4 d'2 d'4  ~ | | %{ bar 66: %} d'4 d'2 d'4  ~ | | %{ bar 67: %} d'4 d'2 d'4  ~ | | %{ bar 68: %} d'4 d'2 d'4  ~ | | %{ bar 69: %} d'4 d'2 d'4  ~ | | %{ bar 70: %} d'4 d'2 d'4  ~ | | %{ bar 71: %} d'4 d'2 d'4  ~ | | %{ bar 72: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 73: %} r4 des'2 d'4  ~ | | %{ bar 74: %} d'4 c''4 r2 | | %{ bar 75: %} R1 | | %{ bar 76: %} c'4 r2. | %{ bar 77: %} R1 | | %{ bar 78: %} a'8 r2. r8 | | %{ bar 79: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 80: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 81: %} r4 d'2 d'4  ~ | | %{ bar 82: %} d'4 d'2 d'4  ~ | | %{ bar 83: %} d'4 d'2 d'4  ~ | | %{ bar 84: %} d'4 d'2 d'4  ~ | | %{ bar 85: %} d'4 d'2 d'4  ~ | | %{ bar 86: %} d'4 d'2 d'4  ~ | | %{ bar 87: %} d'4 d'2 d'4  ~ | | %{ bar 88: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 89: %} r4 des'2 d'4  ~ | | %{ bar 90: %} d'4 c''4 r2 | | %{ bar 91: %} R1 | | %{ bar 92: %} c'4 r2. | %{ bar 93: %} R1 | | %{ bar 94: %} a'8 r2. r8 | | %{ bar 95: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 96: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 97: %} r4 d'2 d'4  ~ | | %{ bar 98: %} d'4 d'2 d'4  ~ | | %{ bar 99: %} d'4 d'2 d'4  ~ | | %{ bar 100: %} d'4 d'2 d'4  ~ | | %{ bar 101: %} d'4 d'2 d'4  ~ | | %{ bar 102: %} d'4 d'2 d'4  ~ | | %{ bar 103: %} d'4 d'2 d'4  ~ | | %{ bar 104: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 105: %} r4 des'2 d'4  ~ | | %{ bar 106: %} d'4 c''4 r2 | | %{ bar 107: %} R1 | | %{ bar 108: %} c'4 r2. | %{ bar 109: %} R1 | | %{ bar 110: %} a'8 r2. r8 | | %{ bar 111: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 112: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 113: %} r4 d'2 d'4  ~ | | %{ bar 114: %} d'4 d'2 d'4  ~ | | %{ bar 115: %} d'4 d'2 d'4  ~ | | %{ bar 116: %} d'4 d'2 d'4  ~ | | %{ bar 117: %} d'4 d'2 d'4  ~ | | %{ bar 118: %} d'4 d'2 d'4  ~ | | %{ bar 119: %} d'4 d'2 d'4  ~ | | %{ bar 120: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 121: %} r4 des'2 d'4  ~ | | %{ bar 122: %} d'4 c''4 r2 | | %{ bar 123: %} R1 | | %{ bar 124: %} c'4 r2. | %{ bar 125: %} R1 | | %{ bar 126: %} a'8 r2. r8 | | %{ bar 127: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 128: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 129: %} r4 d'2 d'4  ~ | | %{ bar 130: %} d'4 d'2 d'4  ~ | | %{ bar 131: %} d'4 d'2 d'4  ~ | | %{ bar 132: %} d'4 d'2 d'4  ~ | | %{ bar 133: %} d'4 d'2 d'4  ~ | | %{ bar 134: %} d'4 d'2 d'4  ~ | | %{ bar 135: %} d'4 d'2 d'4  ~ | | %{ bar 136: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 137: %} r4 des'2 d'4  ~ | | %{ bar 138: %} d'4 c''4 r2 | | %{ bar 139: %} R1 | | %{ bar 140: %} c'4 r2. | %{ bar 141: %} R1 | | %{ bar 142: %} a'8 r2. r8 | | %{ bar 143: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 144: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 145: %} r4 d'2 d'4  ~ | | %{ bar 146: %} d'4 d'2 d'4  ~ | | %{ bar 147: %} d'4 d'2 d'4  ~ | | %{ bar 148: %} d'4 d'2 d'4  ~ | | %{ bar 149: %} d'4 d'2 d'4  ~ | | %{ bar 150: %} d'4 d'2 d'4  ~ | | %{ bar 151: %} d'4 d'2 d'4  ~ | | %{ bar 152: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 153: %} r4 des'2 d'4  ~ | | %{ bar 154: %} d'4 c''4 r2 | | %{ bar 155: %} R1 | | %{ bar 156: %} c'4 r2. | %{ bar 157: %} R1 | | %{ bar 158: %} a'8 r2. r8 | | %{ bar 159: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 160: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 161: %} r4 d'2 d'4  ~ | | %{ bar 162: %} d'4 d'2 d'4  ~ | | %{ bar 163: %} d'4 d'2 d'4  ~ | | %{ bar 164: %} d'4 d'2 d'4  ~ | | %{ bar 165: %} d'4 d'2 d'4  ~ | | %{ bar 166: %} d'4 d'2 d'4  ~ | | %{ bar 167: %} d'4 d'2 d'4  ~ | | %{ bar 168: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 169: %} r4 des'2 d'4  ~ | | %{ bar 170: %} d'4 c''4 r2 | | %{ bar 171: %} R1 | | %{ bar 172: %} c'4 r2. | %{ bar 173: %} R1 | | %{ bar 174: %} a'8 r2. r8 | | %{ bar 175: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 176: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 177: %} r4 d'2 d'4  ~ | | %{ bar 178: %} d'4 d'2 d'4  ~ | | %{ bar 179: %} d'4 d'2 d'4  ~ | | %{ bar 180: %} d'4 d'2 d'4  ~ | | %{ bar 181: %} d'4 d'2 d'4  ~ | | %{ bar 182: %} d'4 d'2 d'4  ~ | | %{ bar 183: %} d'4 d'2 d'4  ~ | | %{ bar 184: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 185: %} r4 des'2 d'4  ~ | | %{ bar 186: %} d'4 c''4 r2 | | %{ bar 187: %} R1 | | %{ bar 188: %} c'4 r2. | %{ bar 189: %} R1 | | %{ bar 190: %} a'8 r2. r8 | | %{ bar 191: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 192: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 193: %} r4 d'2 d'4  ~ | | %{ bar 194: %} d'4 d'2 d'4  ~ | | %{ bar 195: %} d'4 d'2 d'4  ~ | | %{ bar 196: %} d'4 d'2 d'4  ~ | | %{ bar 197: %} d'4 d'2 d'4  ~ | | %{ bar 198: %} d'4 d'2 d'4  ~ | | %{ bar 199: %} d'4 d'2 d'4  ~ | | %{ bar 200: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 201: %} r4 des'2 d'4  ~ | | %{ bar 202: %} d'4 c''4 r2 | | %{ bar 203: %} R1 | | %{ bar 204: %} c'4 r2. | %{ bar 205: %} R1 | | %{ bar 206: %} a'8 r2. r8 | | %{ bar 207: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 208: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 209: %} r4 d'2 d'4  ~ | | %{ bar 210: %} d'4 d'2 d'4  ~ | | %{ bar 211: %} d'4 d'2 d'4  ~ | | %{ bar 212: %} d'4 d'2 d'4  ~ | | %{ bar 213: %} d'4 d'2 d'4  ~ | | %{ bar 214: %} d'4 d'2 d'4  ~ | | %{ bar 215: %} d'4 d'2 d'4  ~ | | %{ bar 216: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 217: %} r4 des'2 d'4  ~ | | %{ bar 218: %} d'4 c''4 r2 | | %{ bar 219: %} R1 | | %{ bar 220: %} c'4 r2. | %{ bar 221: %} R1 | | %{ bar 222: %} a'8 r2. r8 | | %{ bar 223: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 224: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 225: %} r4 d'2 d'4  ~ | | %{ bar 226: %} d'4 d'2 d'4  ~ | | %{ bar 227: %} d'4 d'2 d'4  ~ | | %{ bar 228: %} d'4 d'2 d'4  ~ | | %{ bar 229: %} d'4 d'2 d'4  ~ | | %{ bar 230: %} d'4 d'2 d'4  ~ | | %{ bar 231: %} d'4 d'2 d'4  ~ | | %{ bar 232: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 233: %} r4 des'2 d'4  ~ | | %{ bar 234: %} d'4 c''4 r2 | | %{ bar 235: %} R1 | | %{ bar 236: %} c'4 r2. | %{ bar 237: %} R1 | | %{ bar 238: %} a'8 r2. r8 | | %{ bar 239: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 240: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 241: %} r4 d'2 d'4  ~ | | %{ bar 242: %} d'4 d'2 d'4  ~ | | %{ bar 243: %} d'4 d'2 d'4  ~ | | %{ bar 244: %} d'4 d'2 d'4  ~ | | %{ bar 245: %} d'4 d'2 d'4  ~ | | %{ bar 246: %} d'4 d'2 d'4  ~ | | %{ bar 247: %} d'4 d'2 d'4  ~ | | %{ bar 248: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 249: %} r4 des'2 d'4  ~ | | %{ bar 250: %} d'4 c''4 r2 | | %{ bar 251: %} R1 | | %{ bar 252: %} c'4 r2. | %{ bar 253: %} R1 | | %{ bar 254: %} a'8 r2. r8 | | %{ bar 255: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 256: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 257: %} r4 d'2 d'4  ~ | | %{ bar 258: %} d'4 d'2 d'4  ~ | | %{ bar 259: %} d'4 d'2 d'4  ~ | | %{ bar 260: %} d'4 d'2 d'4  ~ | | %{ bar 261: %} d'4 d'2 d'4  ~ | | %{ bar 262: %} d'4 d'2 d'4  ~ | | %{ bar 263: %} d'4 d'2 d'4  ~ | | %{ bar 264: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 265: %} r4 des'2 d'4  ~ | | %{ bar 266: %} d'4 c''4 r2 | | %{ bar 267: %} R1 | | %{ bar 268: %} c'4 r2. | %{ bar 269: %} R1 | | %{ bar 270: %} a'8 r2. r8 | | %{ bar 271: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 272: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 273: %} r4 d'2 d'4  ~ | | %{ bar 274: %} d'4 d'2 d'4  ~ | | %{ bar 275: %} d'4 d'2 d'4  ~ | | %{ bar 276: %} d'4 d'2 d'4  ~ | | %{ bar 277: %} d'4 d'2 d'4  ~ | | %{ bar 278: %} d'4 d'2 d'4  ~ | | %{ bar 279: %} d'4 d'2 d'4  ~ | | %{ bar 280: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 281: %} r4 des'2 d'4  ~ | | %{ bar 282: %} d'4 c''4 r2 | | %{ bar 283: %} R1 | | %{ bar 284: %} c'4 r2. | %{ bar 285: %} R1 | | %{ bar 286: %} a'8 r2. r8 | | %{ bar 287: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 288: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 289: %} r4 d'2 d'4  ~ | | %{ bar 290: %} d'4 d'2 d'4  ~ | | %{ bar 291: %} d'4 d'2 d'4  ~ | | %{ bar 292: %} d'4 d'2 d'4  ~ | | %{ bar 293: %} d'4 d'2 d'4  ~ | | %{ bar 294: %} d'4 d'2 d'4  ~ | | %{ bar 295: %} d'4 d'2 d'4  ~ | | %{ bar 296: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 297: %} r4 des'2 d'4  ~ | | %{ bar 298: %} d'4 c''4 r2 | | %{ bar 299: %} R1 | | %{ bar 300: %} c'4 r2. | %{ bar 301: %} R1 | | %{ bar 302: %} a'8 r2. r8 | | %{ bar 303: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 304: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 305: %} r4 d'2 d'4  ~ | | %{ bar 306: %} d'4 d'2 d'4  ~ | | %{ bar 307: %} d'4 d'2 d'4  ~ | | %{ bar 308: %} d'4 d'2 d'4  ~ | | %{ bar 309: %} d'4 d'2 d'4  ~ | | %{ bar 310: %} d'4 d'2 d'4  ~ | | %{ bar 311: %} d'4 d'2 d'4  ~ | | %{ bar 312: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 313: %} r4 des'2 d'4  ~ | | %{ bar 314: %} d'4 c''4 r2 | | %{ bar 315: %} R1 | | %{ bar 316: %} c'4 r2. | %{ bar 317: %} R1 | | %{ bar 318: %} a'8 r2. r8 | | %{ bar 319: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 320: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 321: %} r4 d'2 d'4  ~ | | %{ bar 322: %} d'4 d'2 d'4  ~ | | %{ bar 323: %} d'4 d'2 d'4  ~ | | %{ bar 324: %} d'4 d'2 d'4  ~ | | %{ bar 325: %} d'4 d'2 d'4  ~ | | %{ bar 326: %} d'4 d'2 d'4  ~ | | %{ bar 327: %} d'4 d'2 d'4  ~ | | %{ bar 328: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 329: %} r4 des'2 d'4  ~ | | %{ bar 330: %} d'4 c''4 r2 | | %{ bar 331: %} R1 | | %{ bar 332: %} c'4 r2. | %{ bar 333: %} R1 | | %{ bar 334: %} a'8 r2. r8 | | %{ bar 335: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 336: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 337: %} r4 d'2 d'4  ~ | | %{ bar 338: %} d'4 d'2 d'4  ~ | | %{ bar 339: %} d'4 d'2 d'4  ~ | | %{ bar 340: %} d'4 d'2 d'4  ~ | | %{ bar 341: %} d'4 d'2 d'4  ~ | | %{ bar 342: %} d'4 d'2 d'4  ~ | | %{ bar 343: %} d'4 d'2 d'4  ~ | | %{ bar 344: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 345: %} r4 des'2 d'4  ~ | | %{ bar 346: %} d'4 c''4 r2 | | %{ bar 347: %} R1 | | %{ bar 348: %} c'4 r2. | %{ bar 349: %} R1 | | %{ bar 350: %} a'8 r2. r8 | | %{ bar 351: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 352: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 353: %} r4 d'2 d'4  ~ | | %{ bar 354: %} d'4 d'2 d'4  ~ | | %{ bar 355: %} d'4 d'2 d'4  ~ | | %{ bar 356: %} d'4 d'2 d'4  ~ | | %{ bar 357: %} d'4 d'2 d'4  ~ | | %{ bar 358: %} d'4 d'2 d'4  ~ | | %{ bar 359: %} d'4 d'2 d'4  ~ | | %{ bar 360: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 361: %} r4 des'2 d'4  ~ | | %{ bar 362: %} d'4 c''4 r2 | | %{ bar 363: %} R1 | | %{ bar 364: %} c'4 r2. | %{ bar 365: %} R1 | | %{ bar 366: %} a'8 r2. r8 | | %{ bar 367: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 368: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 369: %} r4 d'2 d'4  ~ | | %{ bar 370: %} d'4 d'2 d'4  ~ | | %{ bar 371: %} d'4 d'2 d'4  ~ | | %{ bar 372: %} d'4 d'2 d'4  ~ | | %{ bar 373: %} d'4 d'2 d'4  ~ | | %{ bar 374: %} d'4 d'2 d'4  ~ | | %{ bar 375: %} d'4 d'2 d'4  ~ | | %{ bar 376: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 377: %} r4 des'2 d'4  ~ | | %{ bar 378: %} d'4 c''4 r2 | | %{ bar 379: %} R1 | | %{ bar 380: %} c'4 r2. | %{ bar 381: %} R1 | | %{ bar 382: %} a'8 r2. r8 | | %{ bar 383: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 384: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 385: %} r4 d'2 d'4  ~ | | %{ bar 386: %} d'4 d'2 d'4  ~ | | %{ bar 387: %} d'4 d'2 d'4  ~ | | %{ bar 388: %} d'4 d'2 d'4  ~ | | %{ bar 389: %} d'4 d'2 d'4  ~ | | %{ bar 390: %} d'4 d'2 d'4  ~ | | %{ bar 391: %} d'4 d'2 d'4  ~ | | %{ bar 392: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 393: %} r4 des'2 d'4  ~ | | %{ bar 394: %} d'4 c''4 r2 | | %{ bar 395: %} R1 | | %{ bar 396: %} c'4 r2. | %{ bar 397: %} R1 | | %{ bar 398: %} a'8 r2. r8 | | %{ bar 399: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 400: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 401: %} r4 d'2 d'4  ~ | | %{ bar 402: %} d'4 d'2 d'4  ~ | | %{ bar 403: %} d'4 d'2 d'4  ~ | | %{ bar 404: %} d'4 d'2 d'4  ~ | | %{ bar 405: %} d'4 d'2 d'4  ~ | | %{ bar 406: %} d'4 d'2 d'4  ~ | | %{ bar 407: %} d'4 d'2 d'4  ~ | | %{ bar 408: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 409: %} r4 des'2 d'4  ~ | | %{ bar 410: %} d'4 c''4 r2 | | %{ bar 411: %} R1 | | %{ bar 412: %} c'4 r2. | %{ bar 413: %} R1 | | %{ bar 414: %} a'8 r2. r8 | | %{ bar 415: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 416: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 417: %} r4 d'2 d'4  ~ | | %{ bar 418: %} d'4 d'2 d'4  ~ | | %{ bar 419: %} d'4 d'2 d'4  ~ | | %{ bar 420: %} d'4 d'2 d'4  ~ | | %{ bar 421: %} d'4 d'2 d'4  ~ | | %{ bar 422: %} d'4 d'2 d'4  ~ | | %{ bar 423: %} d'4 d'2 d'4  ~ | | %{ bar 424: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 425: %} r4 des'2 d'4  ~ | | %{ bar 426: %} d'4 c''4 r2 | | %{ bar 427: %} R1 | | %{ bar 428: %} c'4 r2. | %{ bar 429: %} R1 | | %{ bar 430: %} a'8 r2. r8 | | %{ bar 431: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 432: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 433: %} r4 d'2 d'4  ~ | | %{ bar 434: %} d'4 d'2 d'4  ~ | | %{ bar 435: %} d'4 d'2 d'4  ~ | | %{ bar 436: %} d'4 d'2 d'4  ~ | | %{ bar 437: %} d'4 d'2 d'4  ~ | | %{ bar 438: %} d'4 d'2 d'4  ~ | | %{ bar 439: %} d'4 d'2 d'4  ~ | | %{ bar 440: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 441: %} r4 des'2 d'4  ~ | | %{ bar 442: %} d'4 c''4 r2 | | %{ bar 443: %} R1 | | %{ bar 444: %} c'4 r2. | %{ bar 445: %} R1 | | %{ bar 446: %} a'8 r2. r8 | | %{ bar 447: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 448: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 449: %} r4 d'2 d'4  ~ | | %{ bar 450: %} d'4 d'2 d'4  ~ | | %{ bar 451: %} d'4 d'2 d'4  ~ | | %{ bar 452: %} d'4 d'2 d'4  ~ | | %{ bar 453: %} d'4 d'2 d'4  ~ | | %{ bar 454: %} d'4 d'2 d'4  ~ | | %{ bar 455: %} d'4 d'2 d'4  ~ | | %{ bar 456: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 457: %} r4 des'2 d'4  ~ | | %{ bar 458: %} d'4 c''4 r2 | | %{ bar 459: %} R1 | | %{ bar 460: %} c'4 r2. | %{ bar 461: %} R1 | | %{ bar 462: %} a'8 r2. r8 | | %{ bar 463: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 464: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 465: %} r4 d'2 d'4  ~ | | %{ bar 466: %} d'4 d'2 d'4  ~ | | %{ bar 467: %} d'4 d'2 d'4  ~ | | %{ bar 468: %} d'4 d'2 d'4  ~ | | %{ bar 469: %} d'4 d'2 d'4  ~ | | %{ bar 470: %} d'4 d'2 d'4  ~ | | %{ bar 471: %} d'4 d'2 d'4  ~ | | %{ bar 472: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 473: %} r4 des'2 d'4  ~ | | %{ bar 474: %} d'4 c''4 r2 | | %{ bar 475: %} R1 | | %{ bar 476: %} c'4 r2. | %{ bar 477: %} R1 | | %{ bar 478: %} a'8 r2. r8 | | %{ bar 479: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 480: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 481: %} r4 d'2 d'4  ~ | | %{ bar 482: %} d'4 d'2 d'4  ~ | | %{ bar 483: %} d'4 d'2 d'4  ~ | | %{ bar 484: %} d'4 d'2 d'4  ~ | | %{ bar 485: %} d'4 d'2 d'4  ~ | | %{ bar 486: %} d'4 d'2 d'4  ~ | | %{ bar 487: %} d'4 d'2 d'4  ~ | | %{ bar 488: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 489: %} r4 des'2 d'4  ~ | | %{ bar 490: %} d'4 c''4 r2 | | %{ bar 491: %} R1 | | %{ bar 492: %} c'4 r2. | %{ bar 493: %} R1 | | %{ bar 494: %} a'8 r2. r8 | | %{ bar 495: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 496: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 497: %} r4 d'2 d'4  ~ | | %{ bar 498: %} d'4 d'2 d'4  ~ | | %{ bar 499: %} d'4 d'2 d'4  ~ | | %{ bar 500: %} d'4 d'2 d'4  ~ | | %{ bar 501: %} d'4 d'2 d'4  ~ | | %{ bar 502: %} d'4 d'2 d'4  ~ | | %{ bar 503: %} d'4 d'2 d'4  ~ | | %{ bar 504: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 505: %} r4 des'2 d'4  ~ | | %{ bar 506: %} d'4 c''4 r2 | | %{ bar 507: %} R1 | | %{ bar 508: %} c'4 r2. | %{ bar 509: %} R1 | | %{ bar 510: %} a'8 r2. r8 | | %{ bar 511: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 512: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 513: %} r4 d'2 d'4  ~ | | %{ bar 514: %} d'4 d'2 d'4  ~ | | %{ bar 515: %} d'4 d'2 d'4  ~ | | %{ bar 516: %} d'4 d'2 d'4  ~ | | %{ bar 517: %} d'4 d'2 d'4  ~ | | %{ bar 518: %} d'4 d'2 d'4  ~ | | %{ bar 519: %} d'4 d'2 d'4  ~ | | %{ bar 520: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 521: %} r4 des'2 d'4  ~ | | %{ bar 522: %} d'4 c''4 r2 | | %{ bar 523: %} R1 | | %{ bar 524: %} c'4 r2. | %{ bar 525: %} R1 | | %{ bar 526: %} a'8 r2. r8 | | %{ bar 527: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 528: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 529: %} r4 d'2 d'4  ~ | | %{ bar 530: %} d'4 d'2 d'4  ~ | | %{ bar 531: %} d'4 d'2 d'4  ~ | | %{ bar 532: %} d'4 d'2 d'4  ~ | | %{ bar 533: %} d'4 d'2 d'4  ~ | | %{ bar 534: %} d'4 d'2 d'4  ~ | | %{ bar 535: %} d'4 d'2 d'4  ~ | | %{ bar 536: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 537: %} r4 des'2 d'4  ~ | | %{ bar 538: %} d'4 c''4 r2 | | %{ bar 539: %} R1 | | %{ bar 540: %} c'4 r2. | %{ bar 541: %} R1 | | %{ bar 542: %} a'8 r2. r8 | | %{ bar 543: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 544: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 545: %} r4 d'2 d'4  ~ | | %{ bar 546: %} d'4 d'2 d'4  ~ | | %{ bar 547: %} d'4 d'2 d'4  ~ | | %{ bar 548: %} d'4 d'2 d'4  ~ | | %{ bar 549: %} d'4 d'2 d'4  ~ | | %{ bar 550: %} d'4 d'2 d'4  ~ | | %{ bar 551: %} d'4 d'2 d'4  ~ | | %{ bar 552: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 553: %} r4 des'2 d'4  ~ | | %{ bar 554: %} d'4 c''4 r2 | | %{ bar 555: %} R1 | | %{ bar 556: %} c'4 r2. | %{ bar 557: %} R1 | | %{ bar 558: %} a'8 r2. r8 | | %{ bar 559: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 560: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 561: %} r4 d'2 d'4  ~ | | %{ bar 562: %} d'4 d'2 d'4  ~ | | %{ bar 563: %} d'4 d'2 d'4  ~ | | %{ bar 564: %} d'4 d'2 d'4  ~ | | %{ bar 565: %} d'4 d'2 d'4  ~ | | %{ bar 566: %} d'4 d'2 d'4  ~ | | %{ bar 567: %} d'4 d'2 d'4  ~ | | %{ bar 568: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 569: %} r4 des'2 d'4  ~ | | %{ bar 570: %} d'4 c''4 r2 | | %{ bar 571: %} R1 | | %{ bar 572: %} c'4 r2. | %{ bar 573: %} R1 | | %{ bar 574: %} a'8 r2. r8 | | %{ bar 575: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 576: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 577: %} r4 d'2 d'4  ~ | | %{ bar 578: %} d'4 d'2 d'4  ~ | | %{ bar 579: %} d'4 d'2 d'4  ~ | | %{ bar 580: %} d'4 d'2 d'4  ~ | | %{ bar 581: %} d'4 d'2 d'4  ~ | | %{ bar 582: %} d'4 d'2 d'4  ~ | | %{ bar 583: %} d'4 d'2 d'4  ~ | | %{ bar 584: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 585: %} r4 des'2 d'4  ~ | | %{ bar 586: %} d'4 c''4 r2 | | %{ bar 587: %} R1 | | %{ bar 588: %} c'4 r2. | %{ bar 589: %} R1 | | %{ bar 590: %} a'8 r2. r8 | | %{ bar 591: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 592: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 593: %} r4 d'2 d'4  ~ | | %{ bar 594: %} d'4 d'2 d'4  ~ | | %{ bar 595: %} d'4 d'2 d'4  ~ | | %{ bar 596: %} d'4 d'2 d'4  ~ | | %{ bar 597: %} d'4 d'2 d'4  ~ | | %{ bar 598: %} d'4 d'2 d'4  ~ | | %{ bar 599: %} d'4 d'2 d'4  ~ | | %{ bar 600: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 601: %} r4 des'2 d'4  ~ | | %{ bar 602: %} d'4 c''4 r2 | | %{ bar 603: %} R1 | | %{ bar 604: %} c'4 r2. | %{ bar 605: %} R1 | | %{ bar 606: %} a'8 r2. r8 | | %{ bar 607: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 608: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 609: %} r4 d'2 d'4  ~ | | %{ bar 610: %} d'4 d'2 d'4  ~ | | %{ bar 611: %} d'4 d'2 d'4  ~ | | %{ bar 612: %} d'4 d'2 d'4  ~ | | %{ bar 613: %} d'4 d'2 d'4  ~ | | %{ bar 614: %} d'4 d'2 d'4  ~ | | %{ bar 615: %} d'4 d'2 d'4  ~ | | %{ bar 616: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 617: %} r4 des'2 d'4  ~ | | %{ bar 618: %} d'4 c''4 r2 | | %{ bar 619: %} R1 | | %{ bar 620: %} c'4 r2. | %{ bar 621: %} R1 | | %{ bar 622: %} a'8 r2. r8 | | %{ bar 623: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 624: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 625: %} r4 d'2 d'4  ~ | | %{ bar 626: %} d'4 d'2 d'4  ~ | | %{ bar 627: %} d'4 d'2 d'4  ~ | | %{ bar 628: %} d'4 d'2 d'4  ~ | | %{ bar 629: %} d'4 d'2 d'4  ~ | | %{ bar 630: %} d'4 d'2 d'4  ~ | | %{ bar 631: %} d'4 d'2 d'4  ~ | | %{ bar 632: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 633: %} r4 des'2 d'4  ~ | | %{ bar 634: %} d'4 c''4 r2 | | %{ bar 635: %} R1 | | %{ bar 636: %} c'4 r2. | %{ bar 637: %} R1 | | %{ bar 638: %} a'8 r2. r8 | | %{ bar 639: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 640: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 641: %} r4 d'2 d'4  ~ | | %{ bar 642: %} d'4 d'2 d'4  ~ | | %{ bar 643: %} d'4 d'2 d'4  ~ | | %{ bar 644: %} d'4 d'2 d'4  ~ | | %{ bar 645: %} d'4 d'2 d'4  ~ | | %{ bar 646: %} d'4 d'2 d'4  ~ | | %{ bar 647: %} d'4 d'2 d'4  ~ | | %{ bar 648: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 649: %} r4 des'2 d'4  ~ | | %{ bar 650: %} d'4 c''4 r2 | | %{ bar 651: %} R1 | | %{ bar 652: %} c'4 r2. | %{ bar 653: %} R1 | | %{ bar 654: %} a'8 r2. r8 | | %{ bar 655: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 656: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 657: %} r4 d'2 d'4  ~ | | %{ bar 658: %} d'4 d'2 d'4  ~ | | %{ bar 659: %} d'4 d'2 d'4  ~ | | %{ bar 660: %} d'4 d'2 d'4  ~ | | %{ bar 661: %} d'4 d'2 d'4  ~ | | %{ bar 662: %} d'4 d'2 d'4  ~ | | %{ bar 663: %} d'4 d'2 d'4  ~ | | %{ bar 664: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 665: %} r4 des'2 d'4  ~ | | %{ bar 666: %} d'4 c''4 r2 | | %{ bar 667: %} R1 | | %{ bar 668: %} c'4 r2. | %{ bar 669: %} R1 | | %{ bar 670: %} a'8 r2. r8 | | %{ bar 671: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 672: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 673: %} r4 d'2 d'4  ~ | | %{ bar 674: %} d'4 d'2 d'4  ~ | | %{ bar 675: %} d'4 d'2 d'4  ~ | | %{ bar 676: %} d'4 d'2 d'4  ~ | | %{ bar 677: %} d'4 d'2 d'4  ~ | | %{ bar 678: %} d'4 d'2 d'4  ~ | | %{ bar 679: %} d'4 d'2 d'4  ~ | | %{ bar 680: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 681: %} r4 des'2 d'4  ~ | | %{ bar 682: %} d'4 c''4 r2 | | %{ bar 683: %} R1 | | %{ bar 684: %} c'4 r2. | %{ bar 685: %} R1 | | %{ bar 686: %} a'8 r2. r8 | | %{ bar 687: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 688: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 689: %} r4 d'2 d'4  ~ | | %{ bar 690: %} d'4 d'2 d'4  ~ | | %{ bar 691: %} d'4 d'2 d'4  ~ | | %{ bar 692: %} d'4 d'2 d'4  ~ | | %{ bar 693: %} d'4 d'2 d'4  ~ | | %{ bar 694: %} d'4 d'2 d'4  ~ | | %{ bar 695: %} d'4 d'2 d'4  ~ | | %{ bar 696: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 697: %} r4 des'2 d'4  ~ | | %{ bar 698: %} d'4 c''4 r2 | | %{ bar 699: %} R1 | | %{ bar 700: %} c'4 r2. | %{ bar 701: %} R1 | | %{ bar 702: %} a'8 r2. r8 | | %{ bar 703: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 704: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 705: %} r4 d'2 d'4  ~ | | %{ bar 706: %} d'4 d'2 d'4  ~ | | %{ bar 707: %} d'4 d'2 d'4  ~ | | %{ bar 708: %} d'4 d'2 d'4  ~ | | %{ bar 709: %} d'4 d'2 d'4  ~ | | %{ bar 710: %} d'4 d'2 d'4  ~ | | %{ bar 711: %} d'4 d'2 d'4  ~ | | %{ bar 712: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 713: %} r4 des'2 d'4  ~ | | %{ bar 714: %} d'4 c''4 r2 | | %{ bar 715: %} R1 | | %{ bar 716: %} c'4 r2. | %{ bar 717: %} R1 | | %{ bar 718: %} a'8 r2. r8 | | %{ bar 719: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 720: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 721: %} r4 d'2 d'4  ~ | | %{ bar 722: %} d'4 d'2 d'4  ~ | | %{ bar 723: %} d'4 d'2 d'4  ~ | | %{ bar 724: %} d'4 d'2 d'4  ~ | | %{ bar 725: %} d'4 d'2 d'4  ~ | | %{ bar 726: %} d'4 d'2 d'4  ~ | | %{ bar 727: %} d'4 d'2 d'4  ~ | | %{ bar 728: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 729: %} r4 des'2 d'4  ~ | | %{ bar 730: %} d'4 c''4 r2 | | %{ bar 731: %} R1 | | %{ bar 732: %} c'4 r2. | %{ bar 733: %} R1 | | %{ bar 734: %} a'8 r2. r8 | | %{ bar 735: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 736: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 737: %} r4 d'2 d'4  ~ | | %{ bar 738: %} d'4 d'2 d'4  ~ | | %{ bar 739: %} d'4 d'2 d'4  ~ | | %{ bar 740: %} d'4 d'2 d'4  ~ | | %{ bar 741: %} d'4 d'2 d'4  ~ | | %{ bar 742: %} d'4 d'2 d'4  ~ | | %{ bar 743: %} d'4 d'2 d'4  ~ | | %{ bar 744: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 745: %} r4 des'2 d'4  ~ | | %{ bar 746: %} d'4 c''4 r2 | | %{ bar 747: %} R1 | | %{ bar 748: %} c'4 r2. | %{ bar 749: %} R1 | | %{ bar 750: %} a'8 r2. r8 | | %{ bar 751: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 752: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 753: %} r4 d'2 d'4  ~ | | %{ bar 754: %} d'4 d'2 d'4  ~ | | %{ bar 755: %} d'4 d'2 d'4  ~ | | %{ bar 756: %} d'4 d'2 d'4  ~ | | %{ bar 757: %} d'4 d'2 d'4  ~ | | %{ bar 758: %} d'4 d'2 d'4  ~ | | %{ bar 759: %} d'4 d'2 d'4  ~ | | %{ bar 760: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 761: %} r4 des'2 d'4  ~ | | %{ bar 762: %} d'4 c''4 r2 | | %{ bar 763: %} R1 | | %{ bar 764: %} c'4 r2. | %{ bar 765: %} R1 | | %{ bar 766: %} a'8 r2. r8 | | %{ bar 767: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 768: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 769: %} r4 d'2 d'4  ~ | | %{ bar 770: %} d'4 d'2 d'4  ~ | | %{ bar 771: %} d'4 d'2 d'4  ~ | | %{ bar 772: %} d'4 d'2 d'4  ~ | | %{ bar 773: %} d'4 d'2 d'4  ~ | | %{ bar 774: %} d'4 d'2 d'4  ~ | | %{ bar 775: %} d'4 d'2 d'4  ~ | | %{ bar 776: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 777: %} r4 des'2 d'4  ~ | | %{ bar 778: %} d'4 c''4 r2 | | %{ bar 779: %} R1 | | %{ bar 780: %} c'4 r2. | %{ bar 781: %} R1 | | %{ bar 782: %} a'8 r2. r8 | | %{ bar 783: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 784: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 785: %} r4 d'2 d'4  ~ | | %{ bar 786: %} d'4 d'2 d'4  ~ | | %{ bar 787: %} d'4 d'2 d'4  ~ | | %{ bar 788: %} d'4 d'2 d'4  ~ | | %{ bar 789: %} d'4 d'2 d'4  ~ | | %{ bar 790: %} d'4 d'2 d'4  ~ | | %{ bar 791: %} d'4 d'2 d'4  ~ | | %{ bar 792: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 793: %} r4 des'2 d'4  ~ | | %{ bar 794: %} d'4 c''4 r2 | | %{ bar 795: %} R1 | | %{ bar 796: %} c'4 r2. | %{ bar 797: %} R1 | | %{ bar 798: %} a'8 r2. r8 | | %{ bar 799: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 800: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 801: %} r4 d'2 d'4  ~ | | %{ bar 802: %} d'4 d'2 d'4  ~ | | %{ bar 803: %} d'4 d'2 d'4  ~ | | %{ bar 804: %} d'4 d'2 d'4  ~ | | %{ bar 805: %} d'4 d'2 d'4  ~ | | %{ bar 806: %} d'4 d'2 d'4  ~ | | %{ bar 807: %} d'4 d'2 d'4  ~ | | %{ bar 808: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 809: %} r4 des'2 d'4  ~ | | %{ bar 810: %} d'4 c''4 r2 | | %{ bar 811: %} R1 | | %{ bar 812: %} c'4 r2. | %{ bar 813: %} R1 | | %{ bar 814: %} a'8 r2. r8 | | %{ bar 815: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 816: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 817: %} r4 d'2 d'4  ~ | | %{ bar 818: %} d'4 d'2 d'4  ~ | | %{ bar 819: %} d'4 d'2 d'4  ~ | | %{ bar 820: %} d'4 d'2 d'4  ~ | | %{ bar 821: %} d'4 d'2 d'4  ~ | | %{ bar 822: %} d'4 d'2 d'4  ~ | | %{ bar 823: %} d'4 d'2 d'4  ~ | | %{ bar 824: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 825: %} r4 des'2 d'4  ~ | | %{ bar 826: %} d'4 c''4 r2 | | %{ bar 827: %} R1 | | %{ bar 828: %} c'4 r2. | %{ bar 829: %} R1 | | %{ bar 830: %} a'8 r2. r8 | | %{ bar 831: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 832: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 833: %} r4 d'2 d'4  ~ | | %{ bar 834: %} d'4 d'2 d'4  ~ | | %{ bar 835: %} d'4 d'2 d'4  ~ | | %{ bar 836: %} d'4 d'2 d'4  ~ | | %{ bar 837: %} d'4 d'2 d'4  ~ | | %{ bar 838: %} d'4 d'2 d'4  ~ | | %{ bar 839: %} d'4 d'2 d'4  ~ | | %{ bar 840: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 841: %} r4 des'2 d'4  ~ | | %{ bar 842: %} d'4 c''4 r2 | | %{ bar 843: %} R1 | | %{ bar 844: %} c'4 r2. | %{ bar 845: %} R1 | | %{ bar 846: %} a'8 r2. r8 | | %{ bar 847: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 848: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 849: %} r4 d'2 d'4  ~ | | %{ bar 850: %} d'4 d'2 d'4  ~ | | %{ bar 851: %} d'4 d'2 d'4  ~ | | %{ bar 852: %} d'4 d'2 d'4  ~ | | %{ bar 853: %} d'4 d'2 d'4  ~ | | %{ bar 854: %} d'4 d'2 d'4  ~ | | %{ bar 855: %} d'4 d'2 d'4  ~ | | %{ bar 856: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 857: %} r4 des'2 d'4  ~ | | %{ bar 858: %} d'4 c''4 r2 | | %{ bar 859: %} R1 | | %{ bar 860: %} c'4 r2. | %{ bar 861: %} R1 | | %{ bar 862: %} a'8 r2. r8 | | %{ bar 863: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 864: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 865: %} r4 d'2 d'4  ~ | | %{ bar 866: %} d'4 d'2 d'4  ~ | | %{ bar 867: %} d'4 d'2 d'4  ~ | | %{ bar 868: %} d'4 d'2 d'4  ~ | | %{ bar 869: %} d'4 d'2 d'4  ~ | | %{ bar 870: %} d'4 d'2 d'4  ~ | | %{ bar 871: %} d'4 d'2 d'4  ~ | | %{ bar 872: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 873: %} r4 des'2 d'4  ~ | | %{ bar 874: %} d'4 c''4 r2 | | %{ bar 875: %} R1 | | %{ bar 876: %} c'4 r2. | %{ bar 877: %} R1 | | %{ bar 878: %} a'8 r2. r8 | | %{ bar 879: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 880: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 881: %} r4 d'2 d'4  ~ | | %{ bar 882: %} d'4 d'2 d'4  ~ | | %{ bar 883: %} d'4 d'2 d'4  ~ | | %{ bar 884: %} d'4 d'2 d'4  ~ | | %{ bar 885: %} d'4 d'2 d'4  ~ | | %{ bar 886: %} d'4 d'2 d'4  ~ | | %{ bar 887: %} d'4 d'2 d'4  ~ | | %{ bar 888: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 889: %} r4 des'2 d'4  ~ | | %{ bar 890: %} d'4 c''4 r2 | | %{ bar 891: %} R1 | | %{ bar 892: %} c'4 r2. | %{ bar 893: %} R1 | | %{ bar 894: %} a'8 r2. r8 | | %{ bar 895: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 896: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 897: %} r4 d'2 d'4  ~ | | %{ bar 898: %} d'4 d'2 d'4  ~ | | %{ bar 899: %} d'4 d'2 d'4  ~ | | %{ bar 900: %} d'4 d'2 d'4  ~ | | %{ bar 901: %} d'4 d'2 d'4  ~ | | %{ bar 902: %} d'4 d'2 d'4  ~ | | %{ bar 903: %} d'4 d'2 d'4  ~ | | %{ bar 904: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 905: %} r4 des'2 d'4  ~ | | %{ bar 906: %} d'4 c''4 r2 | | %{ bar 907: %} R1 | | %{ bar 908: %} c'4 r2. | %{ bar 909: %} R1 | | %{ bar 910: %} a'8 r2. r8 | | %{ bar 911: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 912: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 913: %} r4 d'2 d'4  ~ | | %{ bar 914: %} d'4 d'2 d'4  ~ | | %{ bar 915: %} d'4 d'2 d'4  ~ | | %{ bar 916: %} d'4 d'2 d'4  ~ | | %{ bar 917: %} d'4 d'2 d'4  ~ | | %{ bar 918: %} d'4 d'2 d'4  ~ | | %{ bar 919: %} d'4 d'2 d'4  ~ | | %{ bar 920: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 921: %} r4 des'2 d'4  ~ | | %{ bar 922: %} d'4 c''4 r2 | | %{ bar 923: %} R1 | | %{ bar 924: %} c'4 r2. | %{ bar 925: %} R1 | | %{ bar 926: %} a'8 r2. r8 | | %{ bar 927: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 928: %} d'32  ~ d'4 d'16  ~ d'4 d'4 r8 r32 | | %{ bar 929: %} r4 d'2 d'4  ~ | | %{ bar 930: %} d'4 d'2 d'4  ~ | | %{ bar 931: %} d'4 d'2 d'4  ~ | | %{ bar 932: %} d'4 d'2 d'4  ~ | | %{ bar 933: %} d'4 d'2 d'4  ~ | | %{ bar 934: %} d'4 d'2 d'4  ~ | | %{ bar 935: %} d'4 d'2 d'4  ~ | | %{ bar 936: %} d'4 d'32  ~ d'4 des'4 r8. r32 | | %{ bar 937: %} r4 des'2 d'4  ~ | | %{ bar 938: %} d'4 c''4 r2 | | %{ bar 939: %} R1 | | %{ bar 940: %} c'4 r2. | %{ bar 941: %} R1 | | %{ bar 942: %} a'8 r2. r8 | | %{ bar 943: %} g'16  ~ g'4 f'8  ~ f'4 e'16  ~ e'4 | | %{ bar 944: %} d'32  ~ d'4 d'16 r2 r8 r32 | } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
