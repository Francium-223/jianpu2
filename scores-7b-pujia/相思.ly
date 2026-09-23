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
6 3 0 0 | q5 - 0 0 q0 | 0 0 0 0 |
2 - 0 0 | - - 0 0 | 0 0 0 0 | 5 5 0 0 | q6 1 0 0 q0 | - 0 2 0 | 0 0 0 0 | 3 5 0 0 | q5 5 6 0 q0 | 0 0 0 0 |
R{ 6 0 0 0 }
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
R{ }
|
q6 5 0 0 q0 | q2 2 0 0 q0 | - 0 2 0 | 0 0 0 0 | 4. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 2 0 | 1' 0 0 0 |
| |
5 5 0 0 | q5 5 6 0 q0 | 5 - 0 0 |
|
q6 5 0 0 q0 | - 0 2 0 | 0 0 0 0 | 2. 0 0 q0 | q4 - - 0 q0 | 1' - 1' 0 | - 1' 0 0 |
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
     \time 4/4  \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 4: %}
 \note-mod "2" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "–" r4
 \note-mod "–" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "3" e'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 12: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \repeat volta 2 { | %{ bar 14: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 } | %{ bar 15: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 17: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | \repeat volta 2 { } | | %{ bar 18: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 19: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 20: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 21: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 22: %}
 \note-mod "4" f'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 23: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 24: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 25: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 26: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 27: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 28: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 29: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 31: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 32: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 33: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 34: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 35: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 36: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 37: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 38: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 39: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 40: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 41: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 42: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 43: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 44: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 45: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 46: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 47: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 48: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 49: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 50: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 51: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 52: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 53: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 54: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 55: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 56: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 57: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 58: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 59: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 60: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 61: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 62: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 63: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 64: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 65: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 66: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 67: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 68: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 69: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 70: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 71: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 72: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 73: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 74: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 75: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 76: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 77: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 78: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 79: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 80: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 81: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 82: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 83: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 84: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 85: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 86: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 87: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 88: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 89: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 90: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 91: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 92: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 93: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 94: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 95: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 96: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 97: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 98: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 99: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 100: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 101: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 102: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 103: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 104: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 105: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 106: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 107: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 108: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 109: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 111: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 112: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 113: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 114: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 115: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 116: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 117: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 118: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 119: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 120: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 121: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 122: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 123: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 124: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 125: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 126: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 127: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 128: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 129: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 130: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 131: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 132: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 133: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 134: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 135: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 136: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 137: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 138: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 139: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 140: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 141: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 142: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 143: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 144: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 145: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 146: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 147: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 148: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 149: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 150: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 151: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 152: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 153: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 154: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 155: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 156: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 157: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 158: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 159: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 160: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 161: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 162: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 163: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 164: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 165: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 166: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 167: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 168: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 169: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 170: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 171: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 172: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 173: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 174: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 175: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 176: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 177: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 178: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 179: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 180: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 181: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 182: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 183: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 184: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 185: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 186: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 187: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 188: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 189: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 190: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 191: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 192: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 193: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 194: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 195: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 196: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 197: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 198: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 199: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 200: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 201: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 202: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 203: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 204: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 205: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 206: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 207: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 208: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 209: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 210: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 211: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 212: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 213: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 214: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 215: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 216: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 217: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 218: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 219: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 220: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 221: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 222: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 223: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 224: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 225: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 226: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 227: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 228: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 229: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 230: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 231: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 232: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 233: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 234: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 235: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 236: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 237: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 238: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 239: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 240: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 241: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 242: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 243: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 244: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 245: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 246: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 247: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 248: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 249: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 250: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 251: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 252: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 253: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 254: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 255: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 256: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 257: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 258: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 259: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 260: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 261: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 262: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 263: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 264: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 265: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 266: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 267: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 268: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 269: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 270: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 271: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 272: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 273: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 274: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 275: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 276: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 277: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 278: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 279: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 280: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 281: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 282: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 283: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 284: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 285: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 286: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 287: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 288: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 289: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 290: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 291: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 292: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 293: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 294: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 295: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 296: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 297: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 298: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 299: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 300: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 301: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 302: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 303: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 304: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 305: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 306: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 307: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 308: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 309: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 310: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 311: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 312: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 313: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 314: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 315: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 316: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 317: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 318: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 319: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 320: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 321: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 322: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 323: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 324: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 325: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 326: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 327: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 328: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 329: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 330: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 331: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 332: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 333: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 334: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 335: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 336: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 337: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 338: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 339: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 340: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 341: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 342: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 343: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 344: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 345: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 346: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 347: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 348: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 349: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 350: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 351: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 352: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 353: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 354: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 355: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 356: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 357: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 358: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 359: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 360: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 361: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 362: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 363: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 364: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 365: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 366: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 367: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 368: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 369: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 370: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 371: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 372: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 373: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 374: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 375: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 376: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 377: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 378: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 379: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 380: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 381: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 382: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 383: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 384: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 385: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 386: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 387: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 388: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 389: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 390: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 391: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 392: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 393: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 394: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 395: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 396: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 397: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 398: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 399: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 400: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 401: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 402: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 403: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 404: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 405: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 406: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 407: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 408: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 409: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 410: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 411: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 412: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 413: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 414: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 415: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 416: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 417: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 418: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 419: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 420: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 421: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 422: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 423: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 424: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 425: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 426: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 427: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 428: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 429: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 430: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 431: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 432: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 433: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 434: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 435: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 436: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 437: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 438: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 439: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 440: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 441: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 442: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 443: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 444: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 445: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 446: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 447: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 448: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 449: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 450: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 451: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 452: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 453: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 454: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 455: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 456: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 457: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 458: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 459: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 460: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 461: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 462: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 463: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 464: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 465: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 466: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 467: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 468: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 469: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 470: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 471: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 472: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 473: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 474: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 475: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 476: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 477: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 478: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 479: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 480: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 481: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 482: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 483: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 484: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 485: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 486: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 487: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 488: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 489: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 490: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 491: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 492: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 493: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 494: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 495: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 496: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 497: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 498: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 499: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 500: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 501: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 502: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 503: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 504: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 505: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 506: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 507: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 508: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 509: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 510: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 511: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 512: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 513: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 514: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 515: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 516: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 517: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 518: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 519: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 520: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 521: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 522: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 523: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 524: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 525: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 526: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 527: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 528: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 529: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 530: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 531: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 532: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 533: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 534: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 535: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 536: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 537: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 538: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 539: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 540: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 541: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 542: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 543: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 544: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 545: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 546: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 547: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 548: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 549: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 550: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 551: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 552: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 553: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 554: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 555: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 556: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 557: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 558: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 559: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 560: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 561: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 562: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 563: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 564: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 565: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 566: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 567: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 568: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 569: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 570: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 571: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 572: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 573: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 574: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 575: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 576: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 577: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 578: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 579: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 580: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 581: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 582: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 583: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 584: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 585: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 586: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 587: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 588: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 589: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 590: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 591: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 592: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 593: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 594: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 595: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 596: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 597: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 598: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 599: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 600: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 601: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 602: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 603: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 604: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 605: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 606: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 607: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 608: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 609: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 610: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 611: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 612: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 613: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 614: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 615: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 616: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 617: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 618: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 619: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 620: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 621: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 622: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 623: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 624: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 625: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 626: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 627: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 628: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 629: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 630: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 631: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 632: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 633: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 634: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 635: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 636: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 637: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 638: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 639: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 640: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 641: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 642: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 643: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 644: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 645: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 646: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 647: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 648: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 649: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 650: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 651: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 652: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 653: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 654: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 655: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 656: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 657: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 658: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 659: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 660: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 661: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 662: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 663: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 664: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 665: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 666: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 667: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 668: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 669: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 670: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 671: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 672: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 673: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 674: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 675: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 676: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 677: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 678: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 679: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 680: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 681: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 682: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 683: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 684: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 685: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 686: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 687: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 688: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 689: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 690: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 691: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 692: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 693: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 694: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 695: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 696: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 697: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 698: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 699: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 700: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 701: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 702: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 703: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 704: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 705: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 706: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 707: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 708: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 709: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 710: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 711: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 712: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 713: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 714: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 715: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 716: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 717: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 718: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 719: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 720: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 721: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 722: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 723: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 724: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 725: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 726: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 727: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 728: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 729: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 730: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | | | %{ bar 731: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 732: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 733: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | | %{ bar 734: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 735: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 736: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 737: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 738: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 739: %}
 \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 740: %}
 \note-mod "–" r4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
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
    \new Staff { \new Voice="X" { \time 4/4 a'4 e'4 r2 | | %{ bar 2: %} g'8  ~ g'4 r2 r8 | | %{ bar 3: %} R1 | | %{ bar 4: %} d'2 r2 | | %{ bar 5: %} R1 | | %{ bar 6: %} R1 | | %{ bar 7: %} g'4 g'4 r2 | | %{ bar 8: %} a'8 c'4 r2 r8 | | %{ bar 9: %} r2 d'4 r4 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'4 g'4 r2 | | %{ bar 12: %} g'8 g'4 a'4 r4 r8 | | %{ bar 13: %} r1 | \repeat volta 2 { | %{ bar 14: %} a'4 r2. } | %{ bar 15: %} g'4 g'4 r2 | | %{ bar 16: %} g'8 g'4 a'4 r4 r8 | | %{ bar 17: %} g'2 r2 | \repeat volta 2 { } | | %{ bar 18: %} a'8 g'4 r2 r8 | | %{ bar 19: %} d'8 d'4 r2 r8 | | %{ bar 20: %} r2 d'4 r4 | | %{ bar 21: %} R1 | | %{ bar 22: %} f'4. r2 r8 | | %{ bar 23: %} f'8  ~ f'2 r4 r8 | | %{ bar 24: %} c''2 c''4 r4 | | %{ bar 25: %} r4 c''4 d'4 r4 | | %{ bar 26: %} c''4 r2. | | | | %{ bar 27: %} g'4 g'4 r2 | | %{ bar 28: %} g'8 g'4 a'4 r4 r8 | | %{ bar 29: %} g'2 r2 | | | %{ bar 30: %} a'8 g'4 r2 r8 | | %{ bar 31: %} r2 d'4 r4 | | %{ bar 32: %} R1 | | %{ bar 33: %} d'4. r2 r8 | | %{ bar 34: %} f'8  ~ f'2 r4 r8 | | %{ bar 35: %} c''2 c''4 r4 | | %{ bar 36: %} r4 c''4 d'4 r4 | | %{ bar 37: %} c''4 r2. | | | | %{ bar 38: %} g'4 g'4 r2 | | %{ bar 39: %} g'8 g'4 a'4 r4 r8 | | %{ bar 40: %} g'2 r2 | | | %{ bar 41: %} a'8 g'4 r2 r8 | | %{ bar 42: %} r2 d'4 r4 | | %{ bar 43: %} R1 | | %{ bar 44: %} d'4. r2 r8 | | %{ bar 45: %} f'8  ~ f'2 r4 r8 | | %{ bar 46: %} c''2 c''4 r4 | | %{ bar 47: %} r4 c''4 d'4 r4 | | %{ bar 48: %} c''4 r2. | | | | %{ bar 49: %} g'4 g'4 r2 | | %{ bar 50: %} g'8 g'4 a'4 r4 r8 | | %{ bar 51: %} g'2 r2 | | | %{ bar 52: %} a'8 g'4 r2 r8 | | %{ bar 53: %} r2 d'4 r4 | | %{ bar 54: %} R1 | | %{ bar 55: %} d'4. r2 r8 | | %{ bar 56: %} f'8  ~ f'2 r4 r8 | | %{ bar 57: %} c''2 c''4 r4 | | %{ bar 58: %} r4 c''4 d'4 r4 | | %{ bar 59: %} c''4 r2. | | | | %{ bar 60: %} g'4 g'4 r2 | | %{ bar 61: %} g'8 g'4 a'4 r4 r8 | | %{ bar 62: %} g'2 r2 | | | %{ bar 63: %} a'8 g'4 r2 r8 | | %{ bar 64: %} r2 d'4 r4 | | %{ bar 65: %} R1 | | %{ bar 66: %} d'4. r2 r8 | | %{ bar 67: %} f'8  ~ f'2 r4 r8 | | %{ bar 68: %} c''2 c''4 r4 | | %{ bar 69: %} r4 c''4 d'4 r4 | | %{ bar 70: %} c''4 r2. | | | | %{ bar 71: %} g'4 g'4 r2 | | %{ bar 72: %} g'8 g'4 a'4 r4 r8 | | %{ bar 73: %} g'2 r2 | | | %{ bar 74: %} a'8 g'4 r2 r8 | | %{ bar 75: %} r2 d'4 r4 | | %{ bar 76: %} R1 | | %{ bar 77: %} d'4. r2 r8 | | %{ bar 78: %} f'8  ~ f'2 r4 r8 | | %{ bar 79: %} c''2 c''4 r4 | | %{ bar 80: %} r4 c''4 d'4 r4 | | %{ bar 81: %} c''4 r2. | | | | %{ bar 82: %} g'4 g'4 r2 | | %{ bar 83: %} g'8 g'4 a'4 r4 r8 | | %{ bar 84: %} g'2 r2 | | | %{ bar 85: %} a'8 g'4 r2 r8 | | %{ bar 86: %} r2 d'4 r4 | | %{ bar 87: %} R1 | | %{ bar 88: %} d'4. r2 r8 | | %{ bar 89: %} f'8  ~ f'2 r4 r8 | | %{ bar 90: %} c''2 c''4 r4 | | %{ bar 91: %} r4 c''4 d'4 r4 | | %{ bar 92: %} c''4 r2. | | | | %{ bar 93: %} g'4 g'4 r2 | | %{ bar 94: %} g'8 g'4 a'4 r4 r8 | | %{ bar 95: %} g'2 r2 | | | %{ bar 96: %} a'8 g'4 r2 r8 | | %{ bar 97: %} r2 d'4 r4 | | %{ bar 98: %} R1 | | %{ bar 99: %} d'4. r2 r8 | | %{ bar 100: %} f'8  ~ f'2 r4 r8 | | %{ bar 101: %} c''2 c''4 r4 | | %{ bar 102: %} r4 c''4 d'4 r4 | | %{ bar 103: %} c''4 r2. | | | | %{ bar 104: %} g'4 g'4 r2 | | %{ bar 105: %} g'8 g'4 a'4 r4 r8 | | %{ bar 106: %} g'2 r2 | | | %{ bar 107: %} a'8 g'4 r2 r8 | | %{ bar 108: %} r2 d'4 r4 | | %{ bar 109: %} R1 | | %{ bar 110: %} d'4. r2 r8 | | %{ bar 111: %} f'8  ~ f'2 r4 r8 | | %{ bar 112: %} c''2 c''4 r4 | | %{ bar 113: %} r4 c''4 d'4 r4 | | %{ bar 114: %} c''4 r2. | | | | %{ bar 115: %} g'4 g'4 r2 | | %{ bar 116: %} g'8 g'4 a'4 r4 r8 | | %{ bar 117: %} g'2 r2 | | | %{ bar 118: %} a'8 g'4 r2 r8 | | %{ bar 119: %} r2 d'4 r4 | | %{ bar 120: %} R1 | | %{ bar 121: %} d'4. r2 r8 | | %{ bar 122: %} f'8  ~ f'2 r4 r8 | | %{ bar 123: %} c''2 c''4 r4 | | %{ bar 124: %} r4 c''4 d'4 r4 | | %{ bar 125: %} c''4 r2. | | | | %{ bar 126: %} g'4 g'4 r2 | | %{ bar 127: %} g'8 g'4 a'4 r4 r8 | | %{ bar 128: %} g'2 r2 | | | %{ bar 129: %} a'8 g'4 r2 r8 | | %{ bar 130: %} r2 d'4 r4 | | %{ bar 131: %} R1 | | %{ bar 132: %} d'4. r2 r8 | | %{ bar 133: %} f'8  ~ f'2 r4 r8 | | %{ bar 134: %} c''2 c''4 r4 | | %{ bar 135: %} r4 c''4 d'4 r4 | | %{ bar 136: %} c''4 r2. | | | | %{ bar 137: %} g'4 g'4 r2 | | %{ bar 138: %} g'8 g'4 a'4 r4 r8 | | %{ bar 139: %} g'2 r2 | | | %{ bar 140: %} a'8 g'4 r2 r8 | | %{ bar 141: %} r2 d'4 r4 | | %{ bar 142: %} R1 | | %{ bar 143: %} d'4. r2 r8 | | %{ bar 144: %} f'8  ~ f'2 r4 r8 | | %{ bar 145: %} c''2 c''4 r4 | | %{ bar 146: %} r4 c''4 d'4 r4 | | %{ bar 147: %} c''4 r2. | | | | %{ bar 148: %} g'4 g'4 r2 | | %{ bar 149: %} g'8 g'4 a'4 r4 r8 | | %{ bar 150: %} g'2 r2 | | | %{ bar 151: %} a'8 g'4 r2 r8 | | %{ bar 152: %} r2 d'4 r4 | | %{ bar 153: %} R1 | | %{ bar 154: %} d'4. r2 r8 | | %{ bar 155: %} f'8  ~ f'2 r4 r8 | | %{ bar 156: %} c''2 c''4 r4 | | %{ bar 157: %} r4 c''4 d'4 r4 | | %{ bar 158: %} c''4 r2. | | | | %{ bar 159: %} g'4 g'4 r2 | | %{ bar 160: %} g'8 g'4 a'4 r4 r8 | | %{ bar 161: %} g'2 r2 | | | %{ bar 162: %} a'8 g'4 r2 r8 | | %{ bar 163: %} r2 d'4 r4 | | %{ bar 164: %} R1 | | %{ bar 165: %} d'4. r2 r8 | | %{ bar 166: %} f'8  ~ f'2 r4 r8 | | %{ bar 167: %} c''2 c''4 r4 | | %{ bar 168: %} r4 c''4 d'4 r4 | | %{ bar 169: %} c''4 r2. | | | | %{ bar 170: %} g'4 g'4 r2 | | %{ bar 171: %} g'8 g'4 a'4 r4 r8 | | %{ bar 172: %} g'2 r2 | | | %{ bar 173: %} a'8 g'4 r2 r8 | | %{ bar 174: %} r2 d'4 r4 | | %{ bar 175: %} R1 | | %{ bar 176: %} d'4. r2 r8 | | %{ bar 177: %} f'8  ~ f'2 r4 r8 | | %{ bar 178: %} c''2 c''4 r4 | | %{ bar 179: %} r4 c''4 d'4 r4 | | %{ bar 180: %} c''4 r2. | | | | %{ bar 181: %} g'4 g'4 r2 | | %{ bar 182: %} g'8 g'4 a'4 r4 r8 | | %{ bar 183: %} g'2 r2 | | | %{ bar 184: %} a'8 g'4 r2 r8 | | %{ bar 185: %} r2 d'4 r4 | | %{ bar 186: %} R1 | | %{ bar 187: %} d'4. r2 r8 | | %{ bar 188: %} f'8  ~ f'2 r4 r8 | | %{ bar 189: %} c''2 c''4 r4 | | %{ bar 190: %} r4 c''4 d'4 r4 | | %{ bar 191: %} c''4 r2. | | | | %{ bar 192: %} g'4 g'4 r2 | | %{ bar 193: %} g'8 g'4 a'4 r4 r8 | | %{ bar 194: %} g'2 r2 | | | %{ bar 195: %} a'8 g'4 r2 r8 | | %{ bar 196: %} r2 d'4 r4 | | %{ bar 197: %} R1 | | %{ bar 198: %} d'4. r2 r8 | | %{ bar 199: %} f'8  ~ f'2 r4 r8 | | %{ bar 200: %} c''2 c''4 r4 | | %{ bar 201: %} r4 c''4 d'4 r4 | | %{ bar 202: %} c''4 r2. | | | | %{ bar 203: %} g'4 g'4 r2 | | %{ bar 204: %} g'8 g'4 a'4 r4 r8 | | %{ bar 205: %} g'2 r2 | | | %{ bar 206: %} a'8 g'4 r2 r8 | | %{ bar 207: %} r2 d'4 r4 | | %{ bar 208: %} R1 | | %{ bar 209: %} d'4. r2 r8 | | %{ bar 210: %} f'8  ~ f'2 r4 r8 | | %{ bar 211: %} c''2 c''4 r4 | | %{ bar 212: %} r4 c''4 d'4 r4 | | %{ bar 213: %} c''4 r2. | | | | %{ bar 214: %} g'4 g'4 r2 | | %{ bar 215: %} g'8 g'4 a'4 r4 r8 | | %{ bar 216: %} g'2 r2 | | | %{ bar 217: %} a'8 g'4 r2 r8 | | %{ bar 218: %} r2 d'4 r4 | | %{ bar 219: %} R1 | | %{ bar 220: %} d'4. r2 r8 | | %{ bar 221: %} f'8  ~ f'2 r4 r8 | | %{ bar 222: %} c''2 c''4 r4 | | %{ bar 223: %} r4 c''4 d'4 r4 | | %{ bar 224: %} c''4 r2. | | | | %{ bar 225: %} g'4 g'4 r2 | | %{ bar 226: %} g'8 g'4 a'4 r4 r8 | | %{ bar 227: %} g'2 r2 | | | %{ bar 228: %} a'8 g'4 r2 r8 | | %{ bar 229: %} r2 d'4 r4 | | %{ bar 230: %} R1 | | %{ bar 231: %} d'4. r2 r8 | | %{ bar 232: %} f'8  ~ f'2 r4 r8 | | %{ bar 233: %} c''2 c''4 r4 | | %{ bar 234: %} r4 c''4 d'4 r4 | | %{ bar 235: %} c''4 r2. | | | | %{ bar 236: %} g'4 g'4 r2 | | %{ bar 237: %} g'8 g'4 a'4 r4 r8 | | %{ bar 238: %} g'2 r2 | | | %{ bar 239: %} a'8 g'4 r2 r8 | | %{ bar 240: %} r2 d'4 r4 | | %{ bar 241: %} R1 | | %{ bar 242: %} d'4. r2 r8 | | %{ bar 243: %} f'8  ~ f'2 r4 r8 | | %{ bar 244: %} c''2 c''4 r4 | | %{ bar 245: %} r4 c''4 d'4 r4 | | %{ bar 246: %} c''4 r2. | | | | %{ bar 247: %} g'4 g'4 r2 | | %{ bar 248: %} g'8 g'4 a'4 r4 r8 | | %{ bar 249: %} g'2 r2 | | | %{ bar 250: %} a'8 g'4 r2 r8 | | %{ bar 251: %} r2 d'4 r4 | | %{ bar 252: %} R1 | | %{ bar 253: %} d'4. r2 r8 | | %{ bar 254: %} f'8  ~ f'2 r4 r8 | | %{ bar 255: %} c''2 c''4 r4 | | %{ bar 256: %} r4 c''4 d'4 r4 | | %{ bar 257: %} c''4 r2. | | | | %{ bar 258: %} g'4 g'4 r2 | | %{ bar 259: %} g'8 g'4 a'4 r4 r8 | | %{ bar 260: %} g'2 r2 | | | %{ bar 261: %} a'8 g'4 r2 r8 | | %{ bar 262: %} r2 d'4 r4 | | %{ bar 263: %} R1 | | %{ bar 264: %} d'4. r2 r8 | | %{ bar 265: %} f'8  ~ f'2 r4 r8 | | %{ bar 266: %} c''2 c''4 r4 | | %{ bar 267: %} r4 c''4 d'4 r4 | | %{ bar 268: %} c''4 r2. | | | | %{ bar 269: %} g'4 g'4 r2 | | %{ bar 270: %} g'8 g'4 a'4 r4 r8 | | %{ bar 271: %} g'2 r2 | | | %{ bar 272: %} a'8 g'4 r2 r8 | | %{ bar 273: %} r2 d'4 r4 | | %{ bar 274: %} R1 | | %{ bar 275: %} d'4. r2 r8 | | %{ bar 276: %} f'8  ~ f'2 r4 r8 | | %{ bar 277: %} c''2 c''4 r4 | | %{ bar 278: %} r4 c''4 d'4 r4 | | %{ bar 279: %} c''4 r2. | | | | %{ bar 280: %} g'4 g'4 r2 | | %{ bar 281: %} g'8 g'4 a'4 r4 r8 | | %{ bar 282: %} g'2 r2 | | | %{ bar 283: %} a'8 g'4 r2 r8 | | %{ bar 284: %} r2 d'4 r4 | | %{ bar 285: %} R1 | | %{ bar 286: %} d'4. r2 r8 | | %{ bar 287: %} f'8  ~ f'2 r4 r8 | | %{ bar 288: %} c''2 c''4 r4 | | %{ bar 289: %} r4 c''4 d'4 r4 | | %{ bar 290: %} c''4 r2. | | | | %{ bar 291: %} g'4 g'4 r2 | | %{ bar 292: %} g'8 g'4 a'4 r4 r8 | | %{ bar 293: %} g'2 r2 | | | %{ bar 294: %} a'8 g'4 r2 r8 | | %{ bar 295: %} r2 d'4 r4 | | %{ bar 296: %} R1 | | %{ bar 297: %} d'4. r2 r8 | | %{ bar 298: %} f'8  ~ f'2 r4 r8 | | %{ bar 299: %} c''2 c''4 r4 | | %{ bar 300: %} r4 c''4 d'4 r4 | | %{ bar 301: %} c''4 r2. | | | | %{ bar 302: %} g'4 g'4 r2 | | %{ bar 303: %} g'8 g'4 a'4 r4 r8 | | %{ bar 304: %} g'2 r2 | | | %{ bar 305: %} a'8 g'4 r2 r8 | | %{ bar 306: %} r2 d'4 r4 | | %{ bar 307: %} R1 | | %{ bar 308: %} d'4. r2 r8 | | %{ bar 309: %} f'8  ~ f'2 r4 r8 | | %{ bar 310: %} c''2 c''4 r4 | | %{ bar 311: %} r4 c''4 d'4 r4 | | %{ bar 312: %} c''4 r2. | | | | %{ bar 313: %} g'4 g'4 r2 | | %{ bar 314: %} g'8 g'4 a'4 r4 r8 | | %{ bar 315: %} g'2 r2 | | | %{ bar 316: %} a'8 g'4 r2 r8 | | %{ bar 317: %} r2 d'4 r4 | | %{ bar 318: %} R1 | | %{ bar 319: %} d'4. r2 r8 | | %{ bar 320: %} f'8  ~ f'2 r4 r8 | | %{ bar 321: %} c''2 c''4 r4 | | %{ bar 322: %} r4 c''4 d'4 r4 | | %{ bar 323: %} c''4 r2. | | | | %{ bar 324: %} g'4 g'4 r2 | | %{ bar 325: %} g'8 g'4 a'4 r4 r8 | | %{ bar 326: %} g'2 r2 | | | %{ bar 327: %} a'8 g'4 r2 r8 | | %{ bar 328: %} r2 d'4 r4 | | %{ bar 329: %} R1 | | %{ bar 330: %} d'4. r2 r8 | | %{ bar 331: %} f'8  ~ f'2 r4 r8 | | %{ bar 332: %} c''2 c''4 r4 | | %{ bar 333: %} r4 c''4 d'4 r4 | | %{ bar 334: %} c''4 r2. | | | | %{ bar 335: %} g'4 g'4 r2 | | %{ bar 336: %} g'8 g'4 a'4 r4 r8 | | %{ bar 337: %} g'2 r2 | | | %{ bar 338: %} a'8 g'4 r2 r8 | | %{ bar 339: %} r2 d'4 r4 | | %{ bar 340: %} R1 | | %{ bar 341: %} d'4. r2 r8 | | %{ bar 342: %} f'8  ~ f'2 r4 r8 | | %{ bar 343: %} c''2 c''4 r4 | | %{ bar 344: %} r4 c''4 d'4 r4 | | %{ bar 345: %} c''4 r2. | | | | %{ bar 346: %} g'4 g'4 r2 | | %{ bar 347: %} g'8 g'4 a'4 r4 r8 | | %{ bar 348: %} g'2 r2 | | | %{ bar 349: %} a'8 g'4 r2 r8 | | %{ bar 350: %} r2 d'4 r4 | | %{ bar 351: %} R1 | | %{ bar 352: %} d'4. r2 r8 | | %{ bar 353: %} f'8  ~ f'2 r4 r8 | | %{ bar 354: %} c''2 c''4 r4 | | %{ bar 355: %} r4 c''4 d'4 r4 | | %{ bar 356: %} c''4 r2. | | | | %{ bar 357: %} g'4 g'4 r2 | | %{ bar 358: %} g'8 g'4 a'4 r4 r8 | | %{ bar 359: %} g'2 r2 | | | %{ bar 360: %} a'8 g'4 r2 r8 | | %{ bar 361: %} r2 d'4 r4 | | %{ bar 362: %} R1 | | %{ bar 363: %} d'4. r2 r8 | | %{ bar 364: %} f'8  ~ f'2 r4 r8 | | %{ bar 365: %} c''2 c''4 r4 | | %{ bar 366: %} r4 c''4 d'4 r4 | | %{ bar 367: %} c''4 r2. | | | | %{ bar 368: %} g'4 g'4 r2 | | %{ bar 369: %} g'8 g'4 a'4 r4 r8 | | %{ bar 370: %} g'2 r2 | | | %{ bar 371: %} a'8 g'4 r2 r8 | | %{ bar 372: %} r2 d'4 r4 | | %{ bar 373: %} R1 | | %{ bar 374: %} d'4. r2 r8 | | %{ bar 375: %} f'8  ~ f'2 r4 r8 | | %{ bar 376: %} c''2 c''4 r4 | | %{ bar 377: %} r4 c''4 d'4 r4 | | %{ bar 378: %} c''4 r2. | | | | %{ bar 379: %} g'4 g'4 r2 | | %{ bar 380: %} g'8 g'4 a'4 r4 r8 | | %{ bar 381: %} g'2 r2 | | | %{ bar 382: %} a'8 g'4 r2 r8 | | %{ bar 383: %} r2 d'4 r4 | | %{ bar 384: %} R1 | | %{ bar 385: %} d'4. r2 r8 | | %{ bar 386: %} f'8  ~ f'2 r4 r8 | | %{ bar 387: %} c''2 c''4 r4 | | %{ bar 388: %} r4 c''4 d'4 r4 | | %{ bar 389: %} c''4 r2. | | | | %{ bar 390: %} g'4 g'4 r2 | | %{ bar 391: %} g'8 g'4 a'4 r4 r8 | | %{ bar 392: %} g'2 r2 | | | %{ bar 393: %} a'8 g'4 r2 r8 | | %{ bar 394: %} r2 d'4 r4 | | %{ bar 395: %} R1 | | %{ bar 396: %} d'4. r2 r8 | | %{ bar 397: %} f'8  ~ f'2 r4 r8 | | %{ bar 398: %} c''2 c''4 r4 | | %{ bar 399: %} r4 c''4 d'4 r4 | | %{ bar 400: %} c''4 r2. | | | | %{ bar 401: %} g'4 g'4 r2 | | %{ bar 402: %} g'8 g'4 a'4 r4 r8 | | %{ bar 403: %} g'2 r2 | | | %{ bar 404: %} a'8 g'4 r2 r8 | | %{ bar 405: %} r2 d'4 r4 | | %{ bar 406: %} R1 | | %{ bar 407: %} d'4. r2 r8 | | %{ bar 408: %} f'8  ~ f'2 r4 r8 | | %{ bar 409: %} c''2 c''4 r4 | | %{ bar 410: %} r4 c''4 d'4 r4 | | %{ bar 411: %} c''4 r2. | | | | %{ bar 412: %} g'4 g'4 r2 | | %{ bar 413: %} g'8 g'4 a'4 r4 r8 | | %{ bar 414: %} g'2 r2 | | | %{ bar 415: %} a'8 g'4 r2 r8 | | %{ bar 416: %} r2 d'4 r4 | | %{ bar 417: %} R1 | | %{ bar 418: %} d'4. r2 r8 | | %{ bar 419: %} f'8  ~ f'2 r4 r8 | | %{ bar 420: %} c''2 c''4 r4 | | %{ bar 421: %} r4 c''4 d'4 r4 | | %{ bar 422: %} c''4 r2. | | | | %{ bar 423: %} g'4 g'4 r2 | | %{ bar 424: %} g'8 g'4 a'4 r4 r8 | | %{ bar 425: %} g'2 r2 | | | %{ bar 426: %} a'8 g'4 r2 r8 | | %{ bar 427: %} r2 d'4 r4 | | %{ bar 428: %} R1 | | %{ bar 429: %} d'4. r2 r8 | | %{ bar 430: %} f'8  ~ f'2 r4 r8 | | %{ bar 431: %} c''2 c''4 r4 | | %{ bar 432: %} r4 c''4 d'4 r4 | | %{ bar 433: %} c''4 r2. | | | | %{ bar 434: %} g'4 g'4 r2 | | %{ bar 435: %} g'8 g'4 a'4 r4 r8 | | %{ bar 436: %} g'2 r2 | | | %{ bar 437: %} a'8 g'4 r2 r8 | | %{ bar 438: %} r2 d'4 r4 | | %{ bar 439: %} R1 | | %{ bar 440: %} d'4. r2 r8 | | %{ bar 441: %} f'8  ~ f'2 r4 r8 | | %{ bar 442: %} c''2 c''4 r4 | | %{ bar 443: %} r4 c''4 d'4 r4 | | %{ bar 444: %} c''4 r2. | | | | %{ bar 445: %} g'4 g'4 r2 | | %{ bar 446: %} g'8 g'4 a'4 r4 r8 | | %{ bar 447: %} g'2 r2 | | | %{ bar 448: %} a'8 g'4 r2 r8 | | %{ bar 449: %} r2 d'4 r4 | | %{ bar 450: %} R1 | | %{ bar 451: %} d'4. r2 r8 | | %{ bar 452: %} f'8  ~ f'2 r4 r8 | | %{ bar 453: %} c''2 c''4 r4 | | %{ bar 454: %} r4 c''4 d'4 r4 | | %{ bar 455: %} c''4 r2. | | | | %{ bar 456: %} g'4 g'4 r2 | | %{ bar 457: %} g'8 g'4 a'4 r4 r8 | | %{ bar 458: %} g'2 r2 | | | %{ bar 459: %} a'8 g'4 r2 r8 | | %{ bar 460: %} r2 d'4 r4 | | %{ bar 461: %} R1 | | %{ bar 462: %} d'4. r2 r8 | | %{ bar 463: %} f'8  ~ f'2 r4 r8 | | %{ bar 464: %} c''2 c''4 r4 | | %{ bar 465: %} r4 c''4 d'4 r4 | | %{ bar 466: %} c''4 r2. | | | | %{ bar 467: %} g'4 g'4 r2 | | %{ bar 468: %} g'8 g'4 a'4 r4 r8 | | %{ bar 469: %} g'2 r2 | | | %{ bar 470: %} a'8 g'4 r2 r8 | | %{ bar 471: %} r2 d'4 r4 | | %{ bar 472: %} R1 | | %{ bar 473: %} d'4. r2 r8 | | %{ bar 474: %} f'8  ~ f'2 r4 r8 | | %{ bar 475: %} c''2 c''4 r4 | | %{ bar 476: %} r4 c''4 d'4 r4 | | %{ bar 477: %} c''4 r2. | | | | %{ bar 478: %} g'4 g'4 r2 | | %{ bar 479: %} g'8 g'4 a'4 r4 r8 | | %{ bar 480: %} g'2 r2 | | | %{ bar 481: %} a'8 g'4 r2 r8 | | %{ bar 482: %} r2 d'4 r4 | | %{ bar 483: %} R1 | | %{ bar 484: %} d'4. r2 r8 | | %{ bar 485: %} f'8  ~ f'2 r4 r8 | | %{ bar 486: %} c''2 c''4 r4 | | %{ bar 487: %} r4 c''4 d'4 r4 | | %{ bar 488: %} c''4 r2. | | | | %{ bar 489: %} g'4 g'4 r2 | | %{ bar 490: %} g'8 g'4 a'4 r4 r8 | | %{ bar 491: %} g'2 r2 | | | %{ bar 492: %} a'8 g'4 r2 r8 | | %{ bar 493: %} r2 d'4 r4 | | %{ bar 494: %} R1 | | %{ bar 495: %} d'4. r2 r8 | | %{ bar 496: %} f'8  ~ f'2 r4 r8 | | %{ bar 497: %} c''2 c''4 r4 | | %{ bar 498: %} r4 c''4 d'4 r4 | | %{ bar 499: %} c''4 r2. | | | | %{ bar 500: %} g'4 g'4 r2 | | %{ bar 501: %} g'8 g'4 a'4 r4 r8 | | %{ bar 502: %} g'2 r2 | | | %{ bar 503: %} a'8 g'4 r2 r8 | | %{ bar 504: %} r2 d'4 r4 | | %{ bar 505: %} R1 | | %{ bar 506: %} d'4. r2 r8 | | %{ bar 507: %} f'8  ~ f'2 r4 r8 | | %{ bar 508: %} c''2 c''4 r4 | | %{ bar 509: %} r4 c''4 d'4 r4 | | %{ bar 510: %} c''4 r2. | | | | %{ bar 511: %} g'4 g'4 r2 | | %{ bar 512: %} g'8 g'4 a'4 r4 r8 | | %{ bar 513: %} g'2 r2 | | | %{ bar 514: %} a'8 g'4 r2 r8 | | %{ bar 515: %} r2 d'4 r4 | | %{ bar 516: %} R1 | | %{ bar 517: %} d'4. r2 r8 | | %{ bar 518: %} f'8  ~ f'2 r4 r8 | | %{ bar 519: %} c''2 c''4 r4 | | %{ bar 520: %} r4 c''4 d'4 r4 | | %{ bar 521: %} c''4 r2. | | | | %{ bar 522: %} g'4 g'4 r2 | | %{ bar 523: %} g'8 g'4 a'4 r4 r8 | | %{ bar 524: %} g'2 r2 | | | %{ bar 525: %} a'8 g'4 r2 r8 | | %{ bar 526: %} r2 d'4 r4 | | %{ bar 527: %} R1 | | %{ bar 528: %} d'4. r2 r8 | | %{ bar 529: %} f'8  ~ f'2 r4 r8 | | %{ bar 530: %} c''2 c''4 r4 | | %{ bar 531: %} r4 c''4 d'4 r4 | | %{ bar 532: %} c''4 r2. | | | | %{ bar 533: %} g'4 g'4 r2 | | %{ bar 534: %} g'8 g'4 a'4 r4 r8 | | %{ bar 535: %} g'2 r2 | | | %{ bar 536: %} a'8 g'4 r2 r8 | | %{ bar 537: %} r2 d'4 r4 | | %{ bar 538: %} R1 | | %{ bar 539: %} d'4. r2 r8 | | %{ bar 540: %} f'8  ~ f'2 r4 r8 | | %{ bar 541: %} c''2 c''4 r4 | | %{ bar 542: %} r4 c''4 d'4 r4 | | %{ bar 543: %} c''4 r2. | | | | %{ bar 544: %} g'4 g'4 r2 | | %{ bar 545: %} g'8 g'4 a'4 r4 r8 | | %{ bar 546: %} g'2 r2 | | | %{ bar 547: %} a'8 g'4 r2 r8 | | %{ bar 548: %} r2 d'4 r4 | | %{ bar 549: %} R1 | | %{ bar 550: %} d'4. r2 r8 | | %{ bar 551: %} f'8  ~ f'2 r4 r8 | | %{ bar 552: %} c''2 c''4 r4 | | %{ bar 553: %} r4 c''4 d'4 r4 | | %{ bar 554: %} c''4 r2. | | | | %{ bar 555: %} g'4 g'4 r2 | | %{ bar 556: %} g'8 g'4 a'4 r4 r8 | | %{ bar 557: %} g'2 r2 | | | %{ bar 558: %} a'8 g'4 r2 r8 | | %{ bar 559: %} r2 d'4 r4 | | %{ bar 560: %} R1 | | %{ bar 561: %} d'4. r2 r8 | | %{ bar 562: %} f'8  ~ f'2 r4 r8 | | %{ bar 563: %} c''2 c''4 r4 | | %{ bar 564: %} r4 c''4 d'4 r4 | | %{ bar 565: %} c''4 r2. | | | | %{ bar 566: %} g'4 g'4 r2 | | %{ bar 567: %} g'8 g'4 a'4 r4 r8 | | %{ bar 568: %} g'2 r2 | | | %{ bar 569: %} a'8 g'4 r2 r8 | | %{ bar 570: %} r2 d'4 r4 | | %{ bar 571: %} R1 | | %{ bar 572: %} d'4. r2 r8 | | %{ bar 573: %} f'8  ~ f'2 r4 r8 | | %{ bar 574: %} c''2 c''4 r4 | | %{ bar 575: %} r4 c''4 d'4 r4 | | %{ bar 576: %} c''4 r2. | | | | %{ bar 577: %} g'4 g'4 r2 | | %{ bar 578: %} g'8 g'4 a'4 r4 r8 | | %{ bar 579: %} g'2 r2 | | | %{ bar 580: %} a'8 g'4 r2 r8 | | %{ bar 581: %} r2 d'4 r4 | | %{ bar 582: %} R1 | | %{ bar 583: %} d'4. r2 r8 | | %{ bar 584: %} f'8  ~ f'2 r4 r8 | | %{ bar 585: %} c''2 c''4 r4 | | %{ bar 586: %} r4 c''4 d'4 r4 | | %{ bar 587: %} c''4 r2. | | | | %{ bar 588: %} g'4 g'4 r2 | | %{ bar 589: %} g'8 g'4 a'4 r4 r8 | | %{ bar 590: %} g'2 r2 | | | %{ bar 591: %} a'8 g'4 r2 r8 | | %{ bar 592: %} r2 d'4 r4 | | %{ bar 593: %} R1 | | %{ bar 594: %} d'4. r2 r8 | | %{ bar 595: %} f'8  ~ f'2 r4 r8 | | %{ bar 596: %} c''2 c''4 r4 | | %{ bar 597: %} r4 c''4 d'4 r4 | | %{ bar 598: %} c''4 r2. | | | | %{ bar 599: %} g'4 g'4 r2 | | %{ bar 600: %} g'8 g'4 a'4 r4 r8 | | %{ bar 601: %} g'2 r2 | | | %{ bar 602: %} a'8 g'4 r2 r8 | | %{ bar 603: %} r2 d'4 r4 | | %{ bar 604: %} R1 | | %{ bar 605: %} d'4. r2 r8 | | %{ bar 606: %} f'8  ~ f'2 r4 r8 | | %{ bar 607: %} c''2 c''4 r4 | | %{ bar 608: %} r4 c''4 d'4 r4 | | %{ bar 609: %} c''4 r2. | | | | %{ bar 610: %} g'4 g'4 r2 | | %{ bar 611: %} g'8 g'4 a'4 r4 r8 | | %{ bar 612: %} g'2 r2 | | | %{ bar 613: %} a'8 g'4 r2 r8 | | %{ bar 614: %} r2 d'4 r4 | | %{ bar 615: %} R1 | | %{ bar 616: %} d'4. r2 r8 | | %{ bar 617: %} f'8  ~ f'2 r4 r8 | | %{ bar 618: %} c''2 c''4 r4 | | %{ bar 619: %} r4 c''4 d'4 r4 | | %{ bar 620: %} c''4 r2. | | | | %{ bar 621: %} g'4 g'4 r2 | | %{ bar 622: %} g'8 g'4 a'4 r4 r8 | | %{ bar 623: %} g'2 r2 | | | %{ bar 624: %} a'8 g'4 r2 r8 | | %{ bar 625: %} r2 d'4 r4 | | %{ bar 626: %} R1 | | %{ bar 627: %} d'4. r2 r8 | | %{ bar 628: %} f'8  ~ f'2 r4 r8 | | %{ bar 629: %} c''2 c''4 r4 | | %{ bar 630: %} r4 c''4 d'4 r4 | | %{ bar 631: %} c''4 r2. | | | | %{ bar 632: %} g'4 g'4 r2 | | %{ bar 633: %} g'8 g'4 a'4 r4 r8 | | %{ bar 634: %} g'2 r2 | | | %{ bar 635: %} a'8 g'4 r2 r8 | | %{ bar 636: %} r2 d'4 r4 | | %{ bar 637: %} R1 | | %{ bar 638: %} d'4. r2 r8 | | %{ bar 639: %} f'8  ~ f'2 r4 r8 | | %{ bar 640: %} c''2 c''4 r4 | | %{ bar 641: %} r4 c''4 d'4 r4 | | %{ bar 642: %} c''4 r2. | | | | %{ bar 643: %} g'4 g'4 r2 | | %{ bar 644: %} g'8 g'4 a'4 r4 r8 | | %{ bar 645: %} g'2 r2 | | | %{ bar 646: %} a'8 g'4 r2 r8 | | %{ bar 647: %} r2 d'4 r4 | | %{ bar 648: %} R1 | | %{ bar 649: %} d'4. r2 r8 | | %{ bar 650: %} f'8  ~ f'2 r4 r8 | | %{ bar 651: %} c''2 c''4 r4 | | %{ bar 652: %} r4 c''4 d'4 r4 | | %{ bar 653: %} c''4 r2. | | | | %{ bar 654: %} g'4 g'4 r2 | | %{ bar 655: %} g'8 g'4 a'4 r4 r8 | | %{ bar 656: %} g'2 r2 | | | %{ bar 657: %} a'8 g'4 r2 r8 | | %{ bar 658: %} r2 d'4 r4 | | %{ bar 659: %} R1 | | %{ bar 660: %} d'4. r2 r8 | | %{ bar 661: %} f'8  ~ f'2 r4 r8 | | %{ bar 662: %} c''2 c''4 r4 | | %{ bar 663: %} r4 c''4 d'4 r4 | | %{ bar 664: %} c''4 r2. | | | | %{ bar 665: %} g'4 g'4 r2 | | %{ bar 666: %} g'8 g'4 a'4 r4 r8 | | %{ bar 667: %} g'2 r2 | | | %{ bar 668: %} a'8 g'4 r2 r8 | | %{ bar 669: %} r2 d'4 r4 | | %{ bar 670: %} R1 | | %{ bar 671: %} d'4. r2 r8 | | %{ bar 672: %} f'8  ~ f'2 r4 r8 | | %{ bar 673: %} c''2 c''4 r4 | | %{ bar 674: %} r4 c''4 d'4 r4 | | %{ bar 675: %} c''4 r2. | | | | %{ bar 676: %} g'4 g'4 r2 | | %{ bar 677: %} g'8 g'4 a'4 r4 r8 | | %{ bar 678: %} g'2 r2 | | | %{ bar 679: %} a'8 g'4 r2 r8 | | %{ bar 680: %} r2 d'4 r4 | | %{ bar 681: %} R1 | | %{ bar 682: %} d'4. r2 r8 | | %{ bar 683: %} f'8  ~ f'2 r4 r8 | | %{ bar 684: %} c''2 c''4 r4 | | %{ bar 685: %} r4 c''4 d'4 r4 | | %{ bar 686: %} c''4 r2. | | | | %{ bar 687: %} g'4 g'4 r2 | | %{ bar 688: %} g'8 g'4 a'4 r4 r8 | | %{ bar 689: %} g'2 r2 | | | %{ bar 690: %} a'8 g'4 r2 r8 | | %{ bar 691: %} r2 d'4 r4 | | %{ bar 692: %} R1 | | %{ bar 693: %} d'4. r2 r8 | | %{ bar 694: %} f'8  ~ f'2 r4 r8 | | %{ bar 695: %} c''2 c''4 r4 | | %{ bar 696: %} r4 c''4 d'4 r4 | | %{ bar 697: %} c''4 r2. | | | | %{ bar 698: %} g'4 g'4 r2 | | %{ bar 699: %} g'8 g'4 a'4 r4 r8 | | %{ bar 700: %} g'2 r2 | | | %{ bar 701: %} a'8 g'4 r2 r8 | | %{ bar 702: %} r2 d'4 r4 | | %{ bar 703: %} R1 | | %{ bar 704: %} d'4. r2 r8 | | %{ bar 705: %} f'8  ~ f'2 r4 r8 | | %{ bar 706: %} c''2 c''4 r4 | | %{ bar 707: %} r4 c''4 d'4 r4 | | %{ bar 708: %} c''4 r2. | | | | %{ bar 709: %} g'4 g'4 r2 | | %{ bar 710: %} g'8 g'4 a'4 r4 r8 | | %{ bar 711: %} g'2 r2 | | | %{ bar 712: %} a'8 g'4 r2 r8 | | %{ bar 713: %} r2 d'4 r4 | | %{ bar 714: %} R1 | | %{ bar 715: %} d'4. r2 r8 | | %{ bar 716: %} f'8  ~ f'2 r4 r8 | | %{ bar 717: %} c''2 c''4 r4 | | %{ bar 718: %} r4 c''4 d'4 r4 | | %{ bar 719: %} c''4 r2. | | | | %{ bar 720: %} g'4 g'4 r2 | | %{ bar 721: %} g'8 g'4 a'4 r4 r8 | | %{ bar 722: %} g'2 r2 | | | %{ bar 723: %} a'8 g'4 r2 r8 | | %{ bar 724: %} r2 d'4 r4 | | %{ bar 725: %} R1 | | %{ bar 726: %} d'4. r2 r8 | | %{ bar 727: %} f'8  ~ f'2 r4 r8 | | %{ bar 728: %} c''2 c''4 r4 | | %{ bar 729: %} r4 c''4 d'4 r4 | | %{ bar 730: %} c''4 r2. | | | | %{ bar 731: %} g'4 g'4 r2 | | %{ bar 732: %} g'8 g'4 a'4 r4 r8 | | %{ bar 733: %} g'2 r2 | | | %{ bar 734: %} a'8 g'4 r2 r8 | | %{ bar 735: %} r2 d'4 r4 | | %{ bar 736: %} R1 | | %{ bar 737: %} d'4. r2 r8 | | %{ bar 738: %} f'8  ~ f'2 r4 r8 | | %{ bar 739: %} c''2 c''4 r4 | | %{ bar 740: %} r4 c''4 r2 | } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
