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
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
5 7 1' 0 | q2' q2' q2' - 0 q0 | 0 0 0 0 |
0 0 0 0 | 4 0. 6 q0 | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
7 1' 2'. q0 | 0 0 0 0 | - 0 0 0 | 0 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | q2 q2 q2 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 q1 q1 0 0 q0 | 0 0 0 0 |
NextScore
subtitle=副歌
0 0 0 0 | 0 0 0 0 | 5 6 3 0 | q2 q2 q2 0 0 q0 | q1 q1 q1 - 0 q0 | 0 0 0 0 |
0 0 0 0 | q1 q1 q1 0 0 q0 | - 0 0 0 | 0 0 0 0 |
7. 1' 2'. | - 0 0 0 | - 0 0 0 |
0 0 0 0 | 4 0. 6. | q3 q3 q3 0 0 q0 | q1 0 0 0 q0 |
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
     \time 4/4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 12: %}
 \note-mod "5" g'4
 \note-mod "7" b'4  \note-mod "1" c''4^.  \note-mod "0" r4 | | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]  ~  \note-mod "–" d''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 16: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 19: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 20: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 21: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 22: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 23: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 24: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 25: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 26: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 27: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 28: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 29: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 30: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 31: %}
 \note-mod "7" b'4
 \note-mod "1" c''4^.  \note-mod "2" d''4.^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 32: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 33: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 34: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 35: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 36: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 37: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 38: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 39: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="X" { \time 4/4 r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} d'8 d'8 d'8 r2 r8 | | %{ bar 10: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 11: %} R1 | | %{ bar 12: %} g'4 b'4 c''4 r4 | | %{ bar 13: %} d''8 d''8 d''8  ~ d''4 r4 r8 | | %{ bar 14: %} R1 | | %{ bar 15: %} R1 | | %{ bar 16: %} f'4 r4. a'4 r8 | | %{ bar 17: %} e'8 e'8 e'8 r2 r8 | | %{ bar 18: %} c'8 c'8 c'8 r2 r8 | | %{ bar 19: %} R1 | | %{ bar 20: %} R1 | | %{ bar 21: %} R1 | | %{ bar 22: %} g'4 a'4 e'4 r4 | | %{ bar 23: %} d'8 d'8 d'8 r2 r8 | | %{ bar 24: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 25: %} R1 | | %{ bar 26: %} R1 | | %{ bar 27: %} c'8 c'8 c'8 r2 r8 | | %{ bar 28: %} d'8 d'8 d'8 r2 r8 | | %{ bar 29: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 30: %} R1 | | %{ bar 31: %} b'4 c''4 d''4. r8 | | %{ bar 32: %} R1 | | %{ bar 33: %} R1 | | %{ bar 34: %} R1 | | %{ bar 35: %} R1 | | %{ bar 36: %} f'4 r4. a'4. | | %{ bar 37: %} e'8 e'8 e'8 r2 r8 | | %{ bar 38: %} c'8 c'8 c'8 r2 r8 | | %{ bar 39: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Y" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 10: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 12: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 13: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 16: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 19: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Z" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} d'8 d'8 d'8 r2 r8 | | %{ bar 10: %} R1 | | %{ bar 11: %} R1 | | %{ bar 12: %} b'4. c''4 d''4.  ~ | | %{ bar 13: %} d''4 r2. | | %{ bar 14: %} R1 | | %{ bar 15: %} R1 | | %{ bar 16: %} f'4 r4. a'4. | | %{ bar 17: %} e'8 e'8 e'8 r2 r8 | | %{ bar 18: %} c'8 c'8 c'8 r2 r8 | | %{ bar 19: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="a" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="b" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="c" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="d" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="e" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="f" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="XW" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="XX" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="XY" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="XZ" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Xa" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Xb" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Xc" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Xd" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Xe" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Xf" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="YW" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="YX" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="YY" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="YZ" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Ya" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Yb" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Yc" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Yd" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Ye" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Yf" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="ZW" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="ZX" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="ZY" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="ZZ" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Za" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Zb" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Zc" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Zd" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="Ze" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="Zf" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="aW" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="aX" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="aY" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="aZ" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="aa" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="ab" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="ac" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="ad" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="ae" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="af" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="bW" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="bX" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="bY" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="bZ" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="ba" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="bb" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="bc" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="bd" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="be" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="bf" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="cW" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="cX" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="cY" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="cZ" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="ca" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="cb" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 c'8 c'8 r2 r8 | | %{ bar 18: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
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
    { \new Voice="cc" {
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
      \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "7" b'4.
 \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4.^.
\=JianpuTie(  ~ | | %{ bar 12: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 15: %}
 \note-mod "4" f'4
 \note-mod "0" r4.  \note-mod "6" a'4. | | %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="副歌"
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
    \new Staff { \new Voice="cd" { r1 | | %{ bar 2: %} R1 | | %{ bar 3: %} g'4 a'4 e'4 r4 | | %{ bar 4: %} d'8 d'8 d'8 r2 r8 | | %{ bar 5: %} c'8 c'8 c'8  ~ c'4 r4 r8 | | %{ bar 6: %} R1 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 c'8 c'8 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} b'4. c''4 d''4.  ~ | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} R1 | | %{ bar 15: %} f'4 r4. a'4. | | %{ bar 16: %} e'8 e'8 e'8 r2 r8 | | %{ bar 17: %} c'8 r2. r8 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="副歌"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
