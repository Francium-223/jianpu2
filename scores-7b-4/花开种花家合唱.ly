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
0 - 0 0 | q3 q2 0 0 0 | q1 q5 q6 0 0 q0 | 0 0 0 0 | 0 0 0 0 |
q7 - 0 0 q0 | q1' - q2' 0 0 | q1 0 - 0 q0 | - 0 0 0 | 0 0 0 0 |
q1 1 - 0 q0 | q1 2 - q1 3 | 0 0 0 0 | q1 4 - 0 q0 | 0 0 0 0 |
subtitle=副歌

NextScore

q1 5 - 0 q0 | q1 6 q1 7 q1 q0 | 1' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 2' - 0 q0 | q2 0 - q2 1 | q2 2 - 0 q0 | - 0 0 0 | 0 0 0 0 |
q2 3 - 0 q0 | q2 4 - q2 5 | 0 0 0 0 | q2 6 - 0 q0 | 0 0 0 0 |

NextScore

q2 7 q2 1' q2 q0 | 2' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 0 - 0 q0 | q3 1 - q3 2 | q3 3 - 0 q0 | - 0 0 0 | 0 0 0 0 |
q3 4 - 0 q0 | q3 5 - q3 6 | 0 0 0 0 | q3 7 - 0 q0 | 0 0 0 0 |

NextScore

q3 1' - 0 q0 | q3 2' q4 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 1 - 0 q0 | q4 2 - q4 3 | q4 4 - 0 q0 | - 0 0 0 | 0 0 0 0 |
q4 5 - 0 q0 | q4 6 - q4 7 | 0 0 0 0 | q4 1' - 0 q0 | 0 0 0 0 |

NextScore

q4 2' - 0 q0 | q5 0 q5 1 0 | 0 0 0 0 | 0 0 0 0 |
q5 2 - 0 q0 | q5 3 - q5 4 | q5 5 - 0 q0 | - 0 0 0 | 0 0 0 0 |
q5 6 - 0 q0 | q5 7 - q5 1' | 0 0 0 0 | q5 2' - 0 q0 | 0 0 0 0 |

NextScore

q6 0 - 0 q0 | q6 1 q6 2 0 | 0 0 0 0 | 0 0 0 0 |
q6 3 - 0 q0 | q6 4 - q6 5 | q6 6 - 0 q0 | - 0 0 0 | 0 0 0 0 |
q6 7 - 0 q0 | q6 1' - q6 2' | 0 0 0 0 | q7 0 - 0 q0 | 0 0 0 0 |

NextScore

q7 1 - 0 q0 | q7 2 q7 3 0 | 0 0 0 0 | 0 0 0 0 |
q7 4 - 0 q0 | q7 5 - q7 6 | q7 7 - 0 q0 | - 0 0 0 | 0 0 0 0 |
q7 1' - 0 q0 | q7 2' - q1' 0 | 0 0 0 0 | q1' 1 - 0 q0 | 0 0 0 0 |

NextScore

q1' 2 - 0 q0 | q1' 3 q1' 4 0 | 0 0 0 0 | 0 0 0 0 |
q1' 5 - 0 q0 | q1' 6 - q1' 7 | q1' 1' - 0 q0 | - 0 0 0 | 0 0 0 0 |
q1' 2' - 0 q0 | q2' 0 - q2' 1 | 0 0 0 0 | q2' 2 - 0 q0 | 0 0 0 0 |

NextScore

q2' 3 - 0 q0 | q2' 4 q2' 5 0 | 0 0 0 0 | 0 0 0 0 |
q2' 6 - 0 q0 | q2' 7 - q2' 1' | q2' 2' - 0 q0 | - 0 0 0 | 0 0 0 0 |
q1 0 0 - q0 | q1 0 1 - q1 | 0 2 0 0 | 0 0 0 0 | q1 0 3 - q0 | 0 0 0 0 |

NextScore

q1 0 4 - q0 | q1 0 5 q1 0 | 6 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 0 7 - q1 | 0 1' 0 0 | q1 0 2' - q0 | - 0 0 0 | 0 0 0 0 |
q1 1 0 - q1 | 1 1 0 0 | 0 0 0 0 | q1 1 2 - q0 | 0 0 0 0 |

NextScore

q1 1 3 - q0 | q1 1 4 q1 1 | 5 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 1 6 - q1 | 1 7 0 0 | q1 1 1' - q0 | - 0 0 0 | 0 0 0 0 |
q1 1 2' - q1 | 2 0 0 0 | 0 0 0 0 | q1 2 1 - q0 | 0 0 0 0 |

NextScore

q1 2 2 - q0 | q1 2 3 q1 2 | 4 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 2 5 - q1 | 2 6 0 0 | q1 2 7 - q0 | - 0 0 0 | 0 0 0 0 |
q1 2 1' - q1 | 2 2' 0 0 | 0 0 0 0 | q1 3 0 - q0 | 0 0 0 0 |

NextScore

q1 3 1 - q0 | q1 3 2 q1 3 | 3 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 3 4 - q1 | 3 5 0 0 | q1 3 6 - q0 | - 0 0 0 | 0 0 0 0 |
q1 3 7 - q1 | 3 1' 0 0 | 0 0 0 0 | q1 3 2' - q0 | 0 0 0 0 |

NextScore

q1 4 0 - q0 | q1 4 1 q1 4 | 2 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 4 3 - q1 | 4 4 0 0 | q1 4 5 - q0 | - 0 0 0 | 0 0 0 0 |
q1 4 6 - q1 | 4 7 0 0 | 0 0 0 0 | q1 4 1' - q0 | 0 0 0 0 |

NextScore

q1 4 2' - q0 | q1 5 0 q1 5 | 1 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 5 2 - q1 | 5 3 0 0 | q1 5 4 - q0 | - 0 0 0 | 0 0 0 0 |
q1 5 5 - q1 | 5 6 0 0 | 0 0 0 0 | q1 5 7 - q0 | 0 0 0 0 |

NextScore

q1 5 1' - q0 | q1 5 2' q1 6 | 0 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 6 1 - q1 | 6 2 0 0 | q1 6 3 - q0 | - 0 0 0 | 0 0 0 0 |
q1 6 4 - q1 | 6 5 0 0 | 0 0 0 0 | q1 6 6 - q0 | 0 0 0 0 |

NextScore

q1 6 7 - q0 | q1 6 1' q1 6 | 2' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 7 0 - q1 | 7 1 0 0 | q1 7 2 - q0 | - 0 0 0 | 0 0 0 0 |
q1 7 3 - q1 | 7 4 0 0 | 0 0 0 0 | q1 7 5 - q0 | 0 0 0 0 |

NextScore

q1 7 6 - q0 | q1 7 7 q1 7 | 1' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 7 2' - q1 | 1' 0 0 0 | q1 1' 1 - q0 | - 0 0 0 | 0 0 0 0 |
q1 1' 2 - q1 | 1' 3 0 0 | 0 0 0 0 | q1 1' 4 - q0 | 0 0 0 0 |

NextScore

q1 1' 5 - q0 | q1 1' 6 q1 1' | 7 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 1' 1' - q1 | 1' 2' 0 0 | q1 2' 0 - q0 | - 0 0 0 | 0 0 0 0 |
q1 2' 1 - q1 | 2' 2 0 0 | 0 0 0 0 | q1 2' 3 - q0 | 0 0 0 0 |

NextScore

q1 2' 4 - q0 | q1 2' 5 q1 2' | 6 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 2' 7 - q1 | 2' 1' 0 0 | q1 2' 2' - q0 | - 0 0 0 | 0 0 0 0 |
q2 0 0 - q2 | 0 1 0 0 | 0 0 0 0 | q2 0 2 - q0 | 0 0 0 0 |

NextScore

q2 0 3 - q0 | q2 0 4 q2 0 | 5 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 0 6 - q2 | 0 7 0 0 | q2 0 1' - q0 | - 0 0 0 | 0 0 0 0 |
q2 0 2' - q2 | 1 0 0 0 | 0 0 0 0 | q2 1 1 - q0 | 0 0 0 0 |

NextScore

q2 1 2 - q0 | q2 1 3 q2 1 | 4 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 1 5 - q2 | 1 6 0 0 | q2 1 7 - q0 | - 0 0 0 | 0 0 0 0 |
q2 1 1' - q2 | 1 2' 0 0 | 0 0 0 0 | q2 2 0 - q0 | 0 0 0 0 |

NextScore

q2 2 1 - q0 | q2 2 2 q2 2 | 3 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 2 4 - q2 | 2 5 0 0 | q2 2 6 - q0 | - 0 0 0 | 0 0 0 0 |
q2 2 7 - q2 | 2 1' 0 0 | 0 0 0 0 | q2 2 2' - q0 | 0 0 0 0 |

NextScore

q2 3 0 - q0 | q2 3 1 q2 3 | 2 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 3 3 - q2 | 3 4 0 0 | q2 3 5 - q0 | - 0 0 0 | 0 0 0 0 |
q2 3 6 - q2 | 3 7 0 0 | 0 0 0 0 | q2 3 1' - q0 | 0 0 0 0 |

NextScore

q2 3 2' - q0 | q2 4 0 q2 4 | 1 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 4 2 - q2 | 4 3 0 0 | q2 4 4 - q0 | - 0 0 0 | 0 0 0 0 |
q2 4 5 - q2 | 4 6 0 0 | 0 0 0 0 | q2 4 7 - q0 | 0 0 0 0 |

NextScore

q2 4 1' - q0 | q2 4 2' q2 5 | 0 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 5 1 - q2 | 5 2 0 0 | q2 5 3 - q0 | - 0 0 0 | 0 0 0 0 |
q2 5 4 - q2 | 5 5 0 0 | 0 0 0 0 | q2 5 6 - q0 | 0 0 0 0 |

NextScore

q2 5 7 - q0 | q2 5 1' q2 5 | 2' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 6 0 - q2 | 6 1 0 0 | q2 6 2 - q0 | - 0 0 0 | 0 0 0 0 |
q2 6 3 - q2 | 6 4 0 0 | 0 0 0 0 | q2 6 5 - q0 | 0 0 0 0 |

NextScore

q2 6 6 - q0 | q2 6 7 q2 6 | 1' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 6 2' - q2 | 7 0 0 0 | q2 7 1 - q0 | - 0 0 0 | 0 0 0 0 |
q2 7 2 - q2 | 7 3 0 0 | 0 0 0 0 | q2 7 4 - q0 | 0 0 0 0 |

NextScore

q2 7 5 - q0 | q2 7 6 q2 7 | 7 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 7 1' - q2 | 7 2' 0 0 | q2 1' 0 - q0 | - 0 0 0 | 0 0 0 0 |
q2 1' 1 - q2 | 1' 2 0 0 | 0 0 0 0 | q2 1' 3 - q0 | 0 0 0 0 |

NextScore

q2 1' 4 - q0 | q2 1' 5 q2 1' | 6 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 1' 7 - q2 | 1' 1' 0 0 | q2 1' 2' - q0 | - 0 0 0 | 0 0 0 0 |
q2 2' 0 - q2 | 2' 1 0 0 | 0 0 0 0 | q2 2' 2 - q0 | 0 0 0 0 |

NextScore

q2 2' 3 - q0 | q2 2' 4 q2 2' | 5 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q2 2' 6 - q2 | 2' 7 0 0 | q2 2' 1' - q0 | - 0 0 0 | 0 0 0 0 |
q2 2' 2' - q3 | 0 0 0 0 | 0 0 0 0 | q3 0 1 - q0 | 0 0 0 0 |

NextScore

q3 0 2 - q0 | q3 0 3 q3 0 | 4 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 0 5 - q3 | 0 6 0 0 | q3 0 7 - q0 | - 0 0 0 | 0 0 0 0 |
q3 0 1' - q3 | 0 2' 0 0 | 0 0 0 0 | q3 1 0 - q0 | 0 0 0 0 |

NextScore

q3 1 1 - q0 | q3 1 2 q3 1 | 3 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 1 4 - q3 | 1 5 0 0 | q3 1 6 - q0 | - 0 0 0 | 0 0 0 0 |
q3 1 7 - q3 | 1 1' 0 0 | 0 0 0 0 | q3 1 2' - q0 | 0 0 0 0 |

NextScore

q3 2 0 - q0 | q3 2 1 q3 2 | 2 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 2 3 - q3 | 2 4 0 0 | q3 2 5 - q0 | - 0 0 0 | 0 0 0 0 |
q3 2 6 - q3 | 2 7 0 0 | 0 0 0 0 | q3 2 1' - q0 | 0 0 0 0 |

NextScore

q3 2 2' - q0 | q3 3 0 q3 3 | 1 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 3 2 - q3 | 3 3 0 0 | q3 3 4 - q0 | - 0 0 0 | 0 0 0 0 |
q3 3 5 - q3 | 3 6 0 0 | 0 0 0 0 | q3 3 7 - q0 | 0 0 0 0 |

NextScore

q3 3 1' - q0 | q3 3 2' q3 4 | 0 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 4 1 - q3 | 4 2 0 0 | q3 4 3 - q0 | - 0 0 0 | 0 0 0 0 |
q3 4 4 - q3 | 4 5 0 0 | 0 0 0 0 | q3 4 6 - q0 | 0 0 0 0 |

NextScore

q3 4 7 - q0 | q3 4 1' q3 4 | 2' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 5 0 - q3 | 5 1 0 0 | q3 5 2 - q0 | - 0 0 0 | 0 0 0 0 |
q3 5 3 - q3 | 5 4 0 0 | 0 0 0 0 | q3 5 5 - q0 | 0 0 0 0 |

NextScore

q3 5 6 - q0 | q3 5 7 q3 5 | 1' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 5 2' - q3 | 6 0 0 0 | q3 6 1 - q0 | - 0 0 0 | 0 0 0 0 |
q3 6 2 - q3 | 6 3 0 0 | 0 0 0 0 | q3 6 4 - q0 | 0 0 0 0 |

NextScore

q3 6 5 - q0 | q3 6 6 q3 6 | 7 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 6 1' - q3 | 6 2' 0 0 | q3 7 0 - q0 | - 0 0 0 | 0 0 0 0 |
q3 7 1 - q3 | 7 2 0 0 | 0 0 0 0 | q3 7 3 - q0 | 0 0 0 0 |

NextScore

q3 7 4 - q0 | q3 7 5 q3 7 | 6 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 7 7 - q3 | 7 1' 0 0 | q3 7 2' - q0 | - 0 0 0 | 0 0 0 0 |
q3 1' 0 - q3 | 1' 1 0 0 | 0 0 0 0 | q3 1' 2 - q0 | 0 0 0 0 |

NextScore

q3 1' 3 - q0 | q3 1' 4 q3 1' | 5 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 1' 6 - q3 | 1' 7 0 0 | q3 1' 1' - q0 | - 0 0 0 | 0 0 0 0 |
q3 1' 2' - q3 | 2' 0 0 0 | 0 0 0 0 | q3 2' 1 - q0 | 0 0 0 0 |

NextScore

q3 2' 2 - q0 | q3 2' 3 q3 2' | 4 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 2' 5 - q3 | 2' 6 0 0 | q3 2' 7 - q0 | - 0 0 0 | 0 0 0 0 |
q3 2' 1' - q3 | 2' 2' 0 0 | 0 0 0 0 | q4 0 0 - q0 | 0 0 0 0 |

NextScore

q4 0 1 - q0 | q4 0 2 q4 0 | 3 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 0 4 - q4 | 0 5 0 0 | q4 0 6 - q0 | - 0 0 0 | 0 0 0 0 |
q4 0 7 - q4 | 0 1' 0 0 | 0 0 0 0 | q4 0 2' - q0 | 0 0 0 0 |

NextScore

q4 1 0 - q0 | q4 1 1 q4 1 | 2 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 1 3 - q4 | 1 4 0 0 | q4 1 5 - q0 | - 0 0 0 | 0 0 0 0 |
q4 1 6 - q4 | 1 7 0 0 | 0 0 0 0 | q4 1 1' - q0 | 0 0 0 0 |

NextScore

q4 1 2' - q0 | q4 2 0 q4 2 | 1 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 2 2 - q4 | 2 3 0 0 | q4 2 4 - q0 | - 0 0 0 | 0 0 0 0 |
q4 2 5 - q4 | 2 6 0 0 | 0 0 0 0 | q4 2 7 - q0 | 0 0 0 0 |

NextScore

q4 2 1' - q0 | q4 2 2' q4 3 | 0 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 3 1 - q4 | 3 2 0 0 | q4 3 3 - q0 | - 0 0 0 | 0 0 0 0 |
q4 3 4 - q4 | 3 5 0 0 | 0 0 0 0 | q4 3 6 - q0 | 0 0 0 0 |

NextScore

q4 3 7 - q0 | q4 3 1' q4 3 | 2' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 4 0 - q4 | 4 1 0 0 | q4 4 2 - q0 | - 0 0 0 | 0 0 0 0 |
q4 4 3 - q4 | 4 4 0 0 | 0 0 0 0 | q4 4 5 - q0 | 0 0 0 0 |

NextScore

q4 4 6 - q0 | q4 4 7 q4 4 | 1' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 4 2' - q4 | 5 0 0 0 | q4 5 1 - q0 | - 0 0 0 | 0 0 0 0 |
q4 5 2 - q4 | 5 3 0 0 | 0 0 0 0 | q4 5 4 - q0 | 0 0 0 0 |

NextScore

q4 5 5 - q0 | q4 5 6 q4 5 | 7 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 5 1' - q4 | 5 2' 0 0 | q4 6 0 - q0 | - 0 0 0 | 0 0 0 0 |
q4 6 1 - q4 | 6 2 0 0 | 0 0 0 0 | q4 6 3 - q0 | 0 0 0 0 |

NextScore

q4 6 4 - q0 | q4 6 5 q4 6 | 6 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 6 7 - q4 | 6 1' 0 0 | q4 6 2' - q0 | - 0 0 0 | 0 0 0 0 |
q4 7 0 - q4 | 7 1 0 0 | 0 0 0 0 | q4 7 2 - q0 | 0 0 0 0 |

NextScore

q4 7 3 - q0 | q4 7 4 q4 7 | 5 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 7 6 - q4 | 7 7 0 0 | q4 7 1' - q0 | - 0 0 0 | 0 0 0 0 |
q4 7 2' - q4 | 1' 0 0 0 | 0 0 0 0 | q4 1' 1 - q0 | 0 0 0 0 |

NextScore

q4 1' 2 - q0 | q4 1' 3 q4 1' | 4 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 1' 5 - q4 | 1' 6 0 0 | q4 1' 7 - q0 | - 0 0 0 | 0 0 0 0 |
q4 1' 1' - q4 | 1' 2' 0 0 | 0 0 0 0 | q4 2' 0 - q0 | 0 0 0 0 |

NextScore

q4 2' 1 - q0 | q4 2' 2 q4 2' | 3 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 2' 4 - q4 | 2' 5 0 0 | q4 2' 6 - q0 | - 0 0 0 | 0 0 0 0 |
q4 2' 7 - q4 | 2' 1' 0 0 | 0 0 0 0 | q4 2' 2' - q0 | 0 0 0 0 |

NextScore

q5 0 0 - q0 | q5 0 1 q5 0 | 2 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 0 3 - q5 | 0 4 0 0 | q5 0 5 - q0 | - 0 0 0 | 0 0 0 0 |
q5 0 6 - q5 | 0 7 0 0 | 0 0 0 0 | q5 0 1' - q0 | 0 0 0 0 |

NextScore

q5 0 2' - q0 | q5 1 0 q5 1 | 1 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 1 2 - q5 | 1 3 0 0 | q5 1 4 - q0 | - 0 0 0 | 0 0 0 0 |
q5 1 5 - q5 | 1 6 0 0 | 0 0 0 0 | q5 1 7 - q0 | 0 0 0 0 |

NextScore

q5 1 1' - q0 | q5 1 2' q5 2 | 0 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 2 1 - q5 | 2 2 0 0 | q5 2 3 - q0 | - 0 0 0 | 0 0 0 0 |
q5 2 4 - q5 | 2 5 0 0 | 0 0 0 0 | q5 2 6 - q0 | 0 0 0 0 |

NextScore

q5 2 7 - q0 | q5 2 1' q5 2 | 2' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 3 0 - q5 | 3 1 0 0 | q5 3 2 - q0 | - 0 0 0 | 0 0 0 0 |
q5 3 3 - q5 | 3 4 0 0 | 0 0 0 0 | q5 3 5 - q0 | 0 0 0 0 |

NextScore

q5 3 6 - q0 | q5 3 7 q5 3 | 1' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 3 2' - q5 | 4 0 0 0 | q5 4 1 - q0 | - 0 0 0 | 0 0 0 0 |
q5 4 2 - q5 | 4 3 0 0 | 0 0 0 0 | q5 4 4 - q0 | 0 0 0 0 |

NextScore

q5 4 5 - q0 | q5 4 6 q5 4 | 7 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 4 1' - q5 | 4 2' 0 0 | q5 5 0 - q0 | - 0 0 0 | 0 0 0 0 |
q5 5 1 - q5 | 5 2 0 0 | 0 0 0 0 | q5 5 3 - q0 | 0 0 0 0 |

NextScore

q5 5 4 - q0 | q5 5 5 q5 5 | 6 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 5 7 - q5 | 5 1' 0 0 | q5 5 2' - q0 | - 0 0 0 | 0 0 0 0 |
q5 6 0 - q5 | 6 1 0 0 | 0 0 0 0 | q5 6 2 - q0 | 0 0 0 0 |

NextScore

q5 6 3 - q0 | q5 6 4 q5 6 | 5 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 6 6 - q5 | 6 7 0 0 | q5 6 1' - q0 | - 0 0 0 | 0 0 0 0 |
q5 6 2' - q5 | 7 0 0 0 | 0 0 0 0 | q5 7 1 - q0 | 0 0 0 0 |

NextScore

q5 7 2 - q0 | q5 7 3 q5 7 | 4 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 7 5 - q5 | 7 6 0 0 | q5 7 7 - q0 | - 0 0 0 | 0 0 0 0 |
q5 7 1' - q5 | 7 2' 0 0 | 0 0 0 0 | q5 1' 0 - q0 | 0 0 0 0 |

NextScore

q5 1' 1 - q0 | q5 1' 2 q5 1' | 3 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 1' 4 - q5 | 1' 5 0 0 | q5 1' 6 - q0 | - 0 0 0 | 0 0 0 0 |
q5 1' 7 - q5 | 1' 1' 0 0 | 0 0 0 0 | q5 1' 2' - q0 | 0 0 0 0 |

NextScore

q5 2' 0 - q0 | q5 2' 1 q5 2' | 2 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q5 2' 3 - q5 | 2' 4 0 0 | q5 2' 5 - q0 | - 0 0 0 | 0 0 0 0 |
q5 2' 6 - q5 | 2' 7 0 0 | 0 0 0 0 | q5 2' 1' - q0 | 0 0 0 0 |

NextScore

q5 2' 2' - q0 | q6 0 0 q6 0 | 1 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q6 0 2 - q6 | 0 3 0 0 | q6 0 4 - q0 | - 0 0 0 | 0 0 0 0 |
q6 0 5 - q6 | 0 6 0 0 | 0 0 0 0 | q6 0 7 - q0 | 0 0 0 0 |

NextScore

q6 0 1' - q0 | q6 0 2' q6 1 | 0 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q6 1 1 - q6 | 1 2 0 0 | q6 1 3 - q0 | - 0 0 0 | 0 0 0 0 |
q6 1 4 - q6 | 1 5 0 0 | 0 0 0 0 | q6 1 6 - q0 | 0 0 0 0 |

NextScore

q6 1 7 - q0 | q6 1 1' q6 1 | 2' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q6 2 0 - q6 | 2 1 0 0 | q6 2 2 - q0 | - 0 0 0 | 0 0 0 0 |
q6 2 3 - q6 | 2 4 0 0 | 0 0 0 0 | q6 2 5 - q0 | 0 0 0 0 |

NextScore

q6 2 6 - q0 | q6 2 7 q6 2 | 1' 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q6 2 2' - q6 | 3 0 0 0 | q6 3 1 - q0 | - 0 0 0 | 0 0 0 0 |
q6 3 2 - q6 | 3 3 0 0 | 0 0 0 0 | q6 3 4 - q0 | 0 0 0 0 |

NextScore

q6 3 5 - q0 | q6 3 6 q6 3 | 7 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q6 3 1' - q6 | 3 2' 0 0 | q6 4 0 - q0 | - 0 0 0 | 0 0 0 0 |
q6 4 1 - q6 | 4 2 0 0 | 0 0 0 0 | q6 4 3 - q0 | 0 0 0 0 |

NextScore

q6 4 4 - q0 | q6 4 5 q6 4 | 6 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q6 4 7 - q6 | 4 1' 0 0 | q6 4 2' - q0 | - 0 0 0 | 0 0 0 0 |
q6 5 0 - q6 | 5 1 0 0 | 0 0 0 0 | q6 5 2 - q0 | 0 0 0 0 |

NextScore

q6 5 3 - q0 | q6 5 4 q6 5 | 5 0 0 0 | 0 0 0 0 | 0 0 0 0 |
q6 5 6 - q6 | 5 7 0 0 | 0 0 0 0 |
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
     \time 4/4  \note-mod "0" r4  \note-mod "–" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  ~  \note-mod "–" b'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[]
 \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "–" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 12: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "3" e'4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="X" { \time 4/4 r1 | | %{ bar 2: %} e'8 d'8 r2. | | %{ bar 3: %} c'8 g'8 a'8 r2 r8 | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} b'8  ~ b'4 r2 r8 | | %{ bar 7: %} c''8  ~ c''4 d''8 r2 | | %{ bar 8: %} c'8 r2. r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 c'2 r4 r8 | | %{ bar 12: %} c'8 d'2 c'8 e'4 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 f'2 r4 r8 | | %{ bar 15: %} r1 | } }
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 3: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "1" c'4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 12: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "5" g'4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Z" { c'8 g'2 r4 r8 | | %{ bar 2: %} c'8 a'4 c'8 b'4 c'8 r8 | | %{ bar 3: %} c''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 d''2 r4 r8 | | %{ bar 7: %} d'8 r2 d'8 c'4 | | %{ bar 8: %} d'8 d'2 r4 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 e'2 r4 r8 | | %{ bar 12: %} d'8 f'2 d'8 g'4 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 a'2 r4 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 2: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "–" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "2" d'4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "6" a'4 | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %}
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
    \new Staff { \new Voice="b" { d'8 b'4 d'8 c''4 d'8 r8 | | %{ bar 2: %} d''4 r2. | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} e'8 r2. r8 | | %{ bar 6: %} e'8 c'2 e'8 d'4 | | %{ bar 7: %} e'8 e'2 r4 r8 | | %{ bar 8: %} R1 | | %{ bar 9: %} R1 | | %{ bar 10: %} e'8 f'2 r4 r8 | | %{ bar 11: %} e'8 g'2 e'8 a'4 | | %{ bar 12: %} R1 | | %{ bar 13: %} e'8 b'2 r4 r8 | | %{ bar 14: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "3" e'4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "7" b'4 | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %}
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
    \new Staff { \new Voice="d" { e'8 c''2 r4 r8 | | %{ bar 2: %} e'8 d''4 f'8 r2 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} f'8 c'2 r4 r8 | | %{ bar 6: %} f'8 d'2 f'8 e'4 | | %{ bar 7: %} f'8 f'2 r4 r8 | | %{ bar 8: %} R1 | | %{ bar 9: %} R1 | | %{ bar 10: %} f'8 g'2 r4 r8 | | %{ bar 11: %} f'8 a'2 f'8 b'4 | | %{ bar 12: %} R1 | | %{ bar 13: %} f'8 c''2 r4 r8 | | %{ bar 14: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "1" c'4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "4" f'4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "1" c''4^. | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %}
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
    \new Staff { \new Voice="f" { f'8 d''2 r4 r8 | | %{ bar 2: %} g'8 r4 g'8 c'4 r4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} g'8 d'2 r4 r8 | | %{ bar 6: %} g'8 e'2 g'8 f'4 | | %{ bar 7: %} g'8 g'2 r4 r8 | | %{ bar 8: %} R1 | | %{ bar 9: %} R1 | | %{ bar 10: %} g'8 a'2 r4 r8 | | %{ bar 11: %} g'8 b'2 g'8 c''4 | | %{ bar 12: %} R1 | | %{ bar 13: %} g'8 d''2 r4 r8 | | %{ bar 14: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "–" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "1" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "2" d'4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "5" g'4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "2" d''4^. | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]   \note-mod "0" r4  \note-mod "–" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %}
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
    \new Staff { \new Voice="XX" { a'8 r2. r8 | | %{ bar 2: %} a'8 c'4 a'8 d'4 r4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} a'8 e'2 r4 r8 | | %{ bar 6: %} a'8 f'2 a'8 g'4 | | %{ bar 7: %} a'8 a'2 r4 r8 | | %{ bar 8: %} R1 | | %{ bar 9: %} R1 | | %{ bar 10: %} a'8 b'2 r4 r8 | | %{ bar 11: %} a'8 c''2 a'8 d''4 | | %{ bar 12: %} R1 | | %{ bar 13: %} b'8 r2. r8 | | %{ bar 14: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]   \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[]
 \note-mod "3" e'4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[]
 \note-mod "6" a'4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[]
 \note-mod "0" r4 | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %}
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
    \new Staff { \new Voice="XZ" { b'8 c'2 r4 r8 | | %{ bar 2: %} b'8 d'4 b'8 e'4 r4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} b'8 f'2 r4 r8 | | %{ bar 6: %} b'8 g'2 b'8 a'4 | | %{ bar 7: %} b'8 b'2 r4 r8 | | %{ bar 8: %} R1 | | %{ bar 9: %} R1 | | %{ bar 10: %} b'8 c''2 r4 r8 | | %{ bar 11: %} b'8 d''2 c''8 r4 | | %{ bar 12: %} R1 | | %{ bar 13: %} c''8 c'2 r4 r8 | | %{ bar 14: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]   \note-mod "3" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[]
 \note-mod "4" f'4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[]
 \note-mod "7" b'4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[]
 \note-mod "1" c'4 | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %}
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
    \new Staff { \new Voice="Xb" { c''8 d'2 r4 r8 | | %{ bar 2: %} c''8 e'4 c''8 f'4 r4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} c''8 g'2 r4 r8 | | %{ bar 6: %} c''8 a'2 c''8 b'4 | | %{ bar 7: %} c''8 c''2 r4 r8 | | %{ bar 8: %} R1 | | %{ bar 9: %} R1 | | %{ bar 10: %} c''8 d''2 r4 r8 | | %{ bar 11: %} d''8 r2 d''8 c'4 | | %{ bar 12: %} R1 | | %{ bar 13: %} d''8 d'2 r4 r8 | | %{ bar 14: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[]
 \note-mod "5" g'4  \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[]
 \note-mod "1" c''4^. | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]  \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Xd" { d''8 e'2 r4 r8 | | %{ bar 2: %} d''8 f'4 d''8 g'4 r4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} d''8 a'2 r4 r8 | | %{ bar 6: %} d''8 b'2 d''8 c''4 | | %{ bar 7: %} d''8 d''2 r4 r8 | | %{ bar 8: %} R1 | | %{ bar 9: %} R1 | | %{ bar 10: %} c'8 r2. r8 | | %{ bar 11: %} c'8 r4 c'2 c'8 | | %{ bar 12: %} r4 d'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 r4 e'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "1" c'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Xf" { c'8 r4 f'2 r8 | | %{ bar 2: %} c'8 r4 g'4 c'8 r4 | | %{ bar 3: %} a'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 r4 b'2 c'8 | | %{ bar 7: %} r4 c''4 r2 | | %{ bar 8: %} c'8 r4 d''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 c'4 r2 c'8 | | %{ bar 12: %} c'4 c'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 c'4 d'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4  \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "1" c'4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "1" c'4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="YX" { c'8 c'4 e'2 r8 | | %{ bar 2: %} c'8 c'4 f'4 c'8 c'4 | | %{ bar 3: %} g'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 c'4 a'2 c'8 | | %{ bar 7: %} c'4 b'4 r2 | | %{ bar 8: %} c'8 c'4 c''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 c'4 d''2 c'8 | | %{ bar 12: %} d'4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 d'4 c'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4  \note-mod "3" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "2" d'4 | | %{ bar 3: %}
 \note-mod "4" f'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "2" d'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "2" d'4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="YZ" { c'8 d'4 d'2 r8 | | %{ bar 2: %} c'8 d'4 e'4 c'8 d'4 | | %{ bar 3: %} f'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 d'4 g'2 c'8 | | %{ bar 7: %} d'4 a'4 r2 | | %{ bar 8: %} c'8 d'4 b'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 d'4 c''2 c'8 | | %{ bar 12: %} d'4 d''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 e'4 r2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "3" e'4 | | %{ bar 3: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "3" e'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "3" e'4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Yb" { c'8 e'4 c'2 r8 | | %{ bar 2: %} c'8 e'4 d'4 c'8 e'4 | | %{ bar 3: %} e'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 e'4 f'2 c'8 | | %{ bar 7: %} e'4 g'4 r2 | | %{ bar 8: %} c'8 e'4 a'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 e'4 b'2 c'8 | | %{ bar 12: %} e'4 c''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 e'4 d''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4  \note-mod "1" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "4" f'4 | | %{ bar 3: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "4" f'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "4" f'4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Yd" { c'8 f'4 r2 r8 | | %{ bar 2: %} c'8 f'4 c'4 c'8 f'4 | | %{ bar 3: %} d'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 f'4 e'2 c'8 | | %{ bar 7: %} f'4 f'4 r2 | | %{ bar 8: %} c'8 f'4 g'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 f'4 a'2 c'8 | | %{ bar 12: %} f'4 b'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 f'4 c''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "5" g'4 | | %{ bar 3: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "5" g'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Yf" { c'8 f'4 d''2 r8 | | %{ bar 2: %} c'8 g'4 r4 c'8 g'4 | | %{ bar 3: %} c'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 g'4 d'2 c'8 | | %{ bar 7: %} g'4 e'4 r2 | | %{ bar 8: %} c'8 g'4 f'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 g'4 g'2 c'8 | | %{ bar 12: %} g'4 a'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 g'4 b'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "5" g'4  \note-mod "2" d''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "6" a'4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "6" a'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "6" a'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="ZX" { c'8 g'4 c''2 r8 | | %{ bar 2: %} c'8 g'4 d''4 c'8 a'4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 a'4 c'2 c'8 | | %{ bar 7: %} a'4 d'4 r2 | | %{ bar 8: %} c'8 a'4 e'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 a'4 f'2 c'8 | | %{ bar 12: %} a'4 g'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 a'4 a'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "6" a'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "6" a'4 | | %{ bar 3: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "7" b'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "7" b'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="ZZ" { c'8 a'4 b'2 r8 | | %{ bar 2: %} c'8 a'4 c''4 c'8 a'4 | | %{ bar 3: %} d''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 b'4 r2 c'8 | | %{ bar 7: %} b'4 c'4 r2 | | %{ bar 8: %} c'8 b'4 d'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 b'4 e'2 c'8 | | %{ bar 12: %} b'4 f'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 b'4 g'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4  \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4 | | %{ bar 3: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "1" c''4^.
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Zb" { c'8 b'4 a'2 r8 | | %{ bar 2: %} c'8 b'4 b'4 c'8 b'4 | | %{ bar 3: %} c''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 b'4 d''2 c'8 | | %{ bar 7: %} c''4 r2. | | %{ bar 8: %} c'8 c''4 c'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 c''4 d'2 c'8 | | %{ bar 12: %} c''4 e'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 c''4 f'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c''4^.  \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "1" c''4^. | | %{ bar 3: %}
 \note-mod "7" b'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "1" c''4^.
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 12: %}
 \note-mod "2" d''4^.
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Zd" { c'8 c''4 g'2 r8 | | %{ bar 2: %} c'8 c''4 a'4 c'8 c''4 | | %{ bar 3: %} b'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 c''4 c''2 c'8 | | %{ bar 7: %} c''4 d''4 r2 | | %{ bar 8: %} c'8 d''4 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8 d''4 c'2 c'8 | | %{ bar 12: %} d''4 d'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} c'8 d''4 e'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d''4^.  \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "2" d''4^. | | %{ bar 3: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
| | %{ bar 7: %}
 \note-mod "2" d''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="Zf" { c'8 d''4 f'2 r8 | | %{ bar 2: %} c'8 d''4 g'4 c'8 d''4 | | %{ bar 3: %} a'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} c'8 d''4 b'2 c'8 | | %{ bar 7: %} d''4 c''4 r2 | | %{ bar 8: %} c'8 d''4 d''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 r2. d'8 | | %{ bar 12: %} r4 c'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 r4 d'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="aX" { d'8 r4 e'2 r8 | | %{ bar 2: %} d'8 r4 f'4 d'8 r4 | | %{ bar 3: %} g'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 r4 a'2 d'8 | | %{ bar 7: %} r4 b'4 r2 | | %{ bar 8: %} d'8 r4 c''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 r4 d''2 d'8 | | %{ bar 12: %} c'4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 c'4 c'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c'4  \note-mod "3" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "1" c'4 | | %{ bar 3: %}
 \note-mod "4" f'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "1" c'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "1" c'4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="aZ" { d'8 c'4 d'2 r8 | | %{ bar 2: %} d'8 c'4 e'4 d'8 c'4 | | %{ bar 3: %} f'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 c'4 g'2 d'8 | | %{ bar 7: %} c'4 a'4 r2 | | %{ bar 8: %} d'8 c'4 b'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 c'4 c''2 d'8 | | %{ bar 12: %} c'4 d''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 d'4 r2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "2" d'4 | | %{ bar 3: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "2" d'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "2" d'4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="ab" { d'8 d'4 c'2 r8 | | %{ bar 2: %} d'8 d'4 d'4 d'8 d'4 | | %{ bar 3: %} e'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 d'4 f'2 d'8 | | %{ bar 7: %} d'4 g'4 r2 | | %{ bar 8: %} d'8 d'4 a'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 d'4 b'2 d'8 | | %{ bar 12: %} d'4 c''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 d'4 d''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "3" e'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "3" e'4  \note-mod "1" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "3" e'4 | | %{ bar 3: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "3" e'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "3" e'4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="ad" { d'8 e'4 r2 r8 | | %{ bar 2: %} d'8 e'4 c'4 d'8 e'4 | | %{ bar 3: %} d'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 e'4 e'2 d'8 | | %{ bar 7: %} e'4 f'4 r2 | | %{ bar 8: %} d'8 e'4 g'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 e'4 a'2 d'8 | | %{ bar 12: %} e'4 b'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 e'4 c''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "4" f'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "4" f'4 | | %{ bar 3: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "4" f'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "4" f'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="af" { d'8 e'4 d''2 r8 | | %{ bar 2: %} d'8 f'4 r4 d'8 f'4 | | %{ bar 3: %} c'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 f'4 d'2 d'8 | | %{ bar 7: %} f'4 e'4 r2 | | %{ bar 8: %} d'8 f'4 f'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 f'4 g'2 d'8 | | %{ bar 12: %} f'4 a'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 f'4 b'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "4" f'4  \note-mod "2" d''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "5" g'4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "5" g'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="bX" { d'8 f'4 c''2 r8 | | %{ bar 2: %} d'8 f'4 d''4 d'8 g'4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 g'4 c'2 d'8 | | %{ bar 7: %} g'4 d'4 r2 | | %{ bar 8: %} d'8 g'4 e'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 g'4 f'2 d'8 | | %{ bar 12: %} g'4 g'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 g'4 a'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "5" g'4 | | %{ bar 3: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "6" a'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "6" a'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "6" a'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="bZ" { d'8 g'4 b'2 r8 | | %{ bar 2: %} d'8 g'4 c''4 d'8 g'4 | | %{ bar 3: %} d''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 a'4 r2 d'8 | | %{ bar 7: %} a'4 c'4 r2 | | %{ bar 8: %} d'8 a'4 d'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 a'4 e'2 d'8 | | %{ bar 12: %} a'4 f'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 a'4 g'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "6" a'4  \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "6" a'4 | | %{ bar 3: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "7" b'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "7" b'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="bb" { d'8 a'4 a'2 r8 | | %{ bar 2: %} d'8 a'4 b'4 d'8 a'4 | | %{ bar 3: %} c''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 a'4 d''2 d'8 | | %{ bar 7: %} b'4 r2. | | %{ bar 8: %} d'8 b'4 c'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 b'4 d'2 d'8 | | %{ bar 12: %} b'4 e'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 b'4 f'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "7" b'4  \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "7" b'4 | | %{ bar 3: %}
 \note-mod "7" b'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "7" b'4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "1" c''4^.
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="bd" { d'8 b'4 g'2 r8 | | %{ bar 2: %} d'8 b'4 a'4 d'8 b'4 | | %{ bar 3: %} b'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 b'4 c''2 d'8 | | %{ bar 7: %} b'4 d''4 r2 | | %{ bar 8: %} d'8 c''4 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 c''4 c'2 d'8 | | %{ bar 12: %} c''4 d'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 c''4 e'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c''4^.  \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "1" c''4^. | | %{ bar 3: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 12: %}
 \note-mod "2" d''4^.
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="bf" { d'8 c''4 f'2 r8 | | %{ bar 2: %} d'8 c''4 g'4 d'8 c''4 | | %{ bar 3: %} a'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 c''4 b'2 d'8 | | %{ bar 7: %} c''4 c''4 r2 | | %{ bar 8: %} d'8 c''4 d''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 d''4 r2 d'8 | | %{ bar 12: %} d''4 c'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} d'8 d''4 d'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d''4^.  \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 \note-mod "2" d''4^. | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
| | %{ bar 7: %}
 \note-mod "2" d''4^.
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="cX" { d'8 d''4 e'2 r8 | | %{ bar 2: %} d'8 d''4 f'4 d'8 d''4 | | %{ bar 3: %} g'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} d'8 d''4 a'2 d'8 | | %{ bar 7: %} d''4 b'4 r2 | | %{ bar 8: %} d'8 d''4 c''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} d'8 d''4 d''2 e'8 | | %{ bar 12: %} R1 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 r4 c'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4  \note-mod "3" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "4" f'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="cZ" { e'8 r4 d'2 r8 | | %{ bar 2: %} e'8 r4 e'4 e'8 r4 | | %{ bar 3: %} f'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 r4 g'2 e'8 | | %{ bar 7: %} r4 a'4 r2 | | %{ bar 8: %} e'8 r4 b'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 r4 c''2 e'8 | | %{ bar 12: %} r4 d''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 c'4 r2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c'4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "1" c'4 | | %{ bar 3: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "1" c'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "1" c'4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="cb" { e'8 c'4 c'2 r8 | | %{ bar 2: %} e'8 c'4 d'4 e'8 c'4 | | %{ bar 3: %} e'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 c'4 f'2 e'8 | | %{ bar 7: %} c'4 g'4 r2 | | %{ bar 8: %} e'8 c'4 a'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 c'4 b'2 e'8 | | %{ bar 12: %} c'4 c''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 c'4 d''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d'4  \note-mod "1" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "2" d'4 | | %{ bar 3: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "2" d'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "2" d'4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="cd" { e'8 d'4 r2 r8 | | %{ bar 2: %} e'8 d'4 c'4 e'8 d'4 | | %{ bar 3: %} d'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 d'4 e'2 e'8 | | %{ bar 7: %} d'4 f'4 r2 | | %{ bar 8: %} e'8 d'4 g'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 d'4 a'2 e'8 | | %{ bar 12: %} d'4 b'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 d'4 c''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="ce" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "3" e'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "3" e'4 | | %{ bar 3: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "3" e'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "3" e'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="cf" { e'8 d'4 d''2 r8 | | %{ bar 2: %} e'8 e'4 r4 e'8 e'4 | | %{ bar 3: %} c'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 e'4 d'2 e'8 | | %{ bar 7: %} e'4 e'4 r2 | | %{ bar 8: %} e'8 e'4 f'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 e'4 g'2 e'8 | | %{ bar 12: %} e'4 a'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 e'4 b'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="dW" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "3" e'4  \note-mod "2" d''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "4" f'4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "4" f'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "4" f'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="dX" { e'8 e'4 c''2 r8 | | %{ bar 2: %} e'8 e'4 d''4 e'8 f'4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 f'4 c'2 e'8 | | %{ bar 7: %} f'4 d'4 r2 | | %{ bar 8: %} e'8 f'4 e'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 f'4 f'2 e'8 | | %{ bar 12: %} f'4 g'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 f'4 a'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="dY" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "4" f'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "4" f'4 | | %{ bar 3: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "5" g'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="dZ" { e'8 f'4 b'2 r8 | | %{ bar 2: %} e'8 f'4 c''4 e'8 f'4 | | %{ bar 3: %} d''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 g'4 r2 e'8 | | %{ bar 7: %} g'4 c'4 r2 | | %{ bar 8: %} e'8 g'4 d'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 g'4 e'2 e'8 | | %{ bar 12: %} g'4 f'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 g'4 g'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="da" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "5" g'4  \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "5" g'4 | | %{ bar 3: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "6" a'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="db" { e'8 g'4 a'2 r8 | | %{ bar 2: %} e'8 g'4 b'4 e'8 g'4 | | %{ bar 3: %} c''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 g'4 d''2 e'8 | | %{ bar 7: %} a'4 r2. | | %{ bar 8: %} e'8 a'4 c'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 a'4 d'2 e'8 | | %{ bar 12: %} a'4 e'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 a'4 f'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="dc" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "6" a'4  \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "6" a'4 | | %{ bar 3: %}
 \note-mod "7" b'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "6" a'4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "7" b'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "7" b'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="dd" { e'8 a'4 g'2 r8 | | %{ bar 2: %} e'8 a'4 a'4 e'8 a'4 | | %{ bar 3: %} b'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 a'4 c''2 e'8 | | %{ bar 7: %} a'4 d''4 r2 | | %{ bar 8: %} e'8 b'4 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 b'4 c'2 e'8 | | %{ bar 12: %} b'4 d'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 b'4 e'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="de" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "7" b'4  \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "7" b'4 | | %{ bar 3: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "7" b'4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "1" c''4^.
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="df" { e'8 b'4 f'2 r8 | | %{ bar 2: %} e'8 b'4 g'4 e'8 b'4 | | %{ bar 3: %} a'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 b'4 b'2 e'8 | | %{ bar 7: %} b'4 c''4 r2 | | %{ bar 8: %} e'8 b'4 d''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 c''4 r2 e'8 | | %{ bar 12: %} c''4 c'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 c''4 d'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="eW" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c''4^.  \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "1" c''4^. | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "1" c''4^.
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="eX" { e'8 c''4 e'2 r8 | | %{ bar 2: %} e'8 c''4 f'4 e'8 c''4 | | %{ bar 3: %} g'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 c''4 a'2 e'8 | | %{ bar 7: %} c''4 b'4 r2 | | %{ bar 8: %} e'8 c''4 c''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 c''4 d''2 e'8 | | %{ bar 12: %} d''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} e'8 d''4 c'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="eY" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d''4^.  \note-mod "3" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 \note-mod "2" d''4^. | | %{ bar 3: %}
 \note-mod "4" f'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 7: %}
 \note-mod "2" d''4^.
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
| | %{ bar 12: %}
 \note-mod "2" d''4^.
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="eZ" { e'8 d''4 d'2 r8 | | %{ bar 2: %} e'8 d''4 e'4 e'8 d''4 | | %{ bar 3: %} f'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} e'8 d''4 g'2 e'8 | | %{ bar 7: %} d''4 a'4 r2 | | %{ bar 8: %} e'8 d''4 b'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} e'8 d''4 c''2 e'8 | | %{ bar 12: %} d''4 d''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 r2. r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="ea" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="eb" { f'8 r4 c'2 r8 | | %{ bar 2: %} f'8 r4 d'4 f'8 r4 | | %{ bar 3: %} e'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 r4 f'2 f'8 | | %{ bar 7: %} r4 g'4 r2 | | %{ bar 8: %} f'8 r4 a'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 r4 b'2 f'8 | | %{ bar 12: %} r4 c''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 r4 d''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="ec" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c'4  \note-mod "1" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "1" c'4 | | %{ bar 3: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "1" c'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "1" c'4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="ed" { f'8 c'4 r2 r8 | | %{ bar 2: %} f'8 c'4 c'4 f'8 c'4 | | %{ bar 3: %} d'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 c'4 e'2 f'8 | | %{ bar 7: %} c'4 f'4 r2 | | %{ bar 8: %} f'8 c'4 g'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 c'4 a'2 f'8 | | %{ bar 12: %} c'4 b'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 c'4 c''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="ee" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "2" d'4 | | %{ bar 3: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "2" d'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "2" d'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="ef" { f'8 c'4 d''2 r8 | | %{ bar 2: %} f'8 d'4 r4 f'8 d'4 | | %{ bar 3: %} c'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 d'4 d'2 f'8 | | %{ bar 7: %} d'4 e'4 r2 | | %{ bar 8: %} f'8 d'4 f'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 d'4 g'2 f'8 | | %{ bar 12: %} d'4 a'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 d'4 b'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="fW" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d'4  \note-mod "2" d''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "3" e'4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "3" e'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "3" e'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="fX" { f'8 d'4 c''2 r8 | | %{ bar 2: %} f'8 d'4 d''4 f'8 e'4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 e'4 c'2 f'8 | | %{ bar 7: %} e'4 d'4 r2 | | %{ bar 8: %} f'8 e'4 e'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 e'4 f'2 f'8 | | %{ bar 12: %} e'4 g'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 e'4 a'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="fY" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "3" e'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "3" e'4 | | %{ bar 3: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "4" f'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "4" f'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "4" f'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="fZ" { f'8 e'4 b'2 r8 | | %{ bar 2: %} f'8 e'4 c''4 f'8 e'4 | | %{ bar 3: %} d''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 f'4 r2 f'8 | | %{ bar 7: %} f'4 c'4 r2 | | %{ bar 8: %} f'8 f'4 d'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 f'4 e'2 f'8 | | %{ bar 12: %} f'4 f'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 f'4 g'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="fa" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "4" f'4  \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "4" f'4 | | %{ bar 3: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "5" g'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="fb" { f'8 f'4 a'2 r8 | | %{ bar 2: %} f'8 f'4 b'4 f'8 f'4 | | %{ bar 3: %} c''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 f'4 d''2 f'8 | | %{ bar 7: %} g'4 r2. | | %{ bar 8: %} f'8 g'4 c'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 g'4 d'2 f'8 | | %{ bar 12: %} g'4 e'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 g'4 f'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="fc" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "5" g'4  \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "5" g'4 | | %{ bar 3: %}
 \note-mod "7" b'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "6" a'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "6" a'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="fd" { f'8 g'4 g'2 r8 | | %{ bar 2: %} f'8 g'4 a'4 f'8 g'4 | | %{ bar 3: %} b'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 g'4 c''2 f'8 | | %{ bar 7: %} g'4 d''4 r2 | | %{ bar 8: %} f'8 a'4 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 a'4 c'2 f'8 | | %{ bar 12: %} a'4 d'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 a'4 e'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="fe" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "6" a'4  \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "6" a'4 | | %{ bar 3: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "6" a'4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "7" b'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "7" b'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="ff" { f'8 a'4 f'2 r8 | | %{ bar 2: %} f'8 a'4 g'4 f'8 a'4 | | %{ bar 3: %} a'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 a'4 b'2 f'8 | | %{ bar 7: %} a'4 c''4 r2 | | %{ bar 8: %} f'8 a'4 d''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 b'4 r2 f'8 | | %{ bar 12: %} b'4 c'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 b'4 d'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XWW" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "7" b'4  \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "7" b'4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "7" b'4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XWX" { f'8 b'4 e'2 r8 | | %{ bar 2: %} f'8 b'4 f'4 f'8 b'4 | | %{ bar 3: %} g'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 b'4 a'2 f'8 | | %{ bar 7: %} b'4 b'4 r2 | | %{ bar 8: %} f'8 b'4 c''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 b'4 d''2 f'8 | | %{ bar 12: %} c''4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 c''4 c'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XWY" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c''4^.  \note-mod "3" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "1" c''4^. | | %{ bar 3: %}
 \note-mod "4" f'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "1" c''4^.
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "1" c''4^.
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XWZ" { f'8 c''4 d'2 r8 | | %{ bar 2: %} f'8 c''4 e'4 f'8 c''4 | | %{ bar 3: %} f'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 c''4 g'2 f'8 | | %{ bar 7: %} c''4 a'4 r2 | | %{ bar 8: %} f'8 c''4 b'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 c''4 c''2 f'8 | | %{ bar 12: %} c''4 d''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 d''4 r2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XWa" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d''4^.  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 \note-mod "2" d''4^. | | %{ bar 3: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 7: %}
 \note-mod "2" d''4^.
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
| | %{ bar 12: %}
 \note-mod "2" d''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XWb" { f'8 d''4 c'2 r8 | | %{ bar 2: %} f'8 d''4 d'4 f'8 d''4 | | %{ bar 3: %} e'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} f'8 d''4 f'2 f'8 | | %{ bar 7: %} d''4 g'4 r2 | | %{ bar 8: %} f'8 d''4 a'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} f'8 d''4 b'2 f'8 | | %{ bar 12: %} d''4 c''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} f'8 d''4 d''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XWc" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4  \note-mod "1" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XWd" { g'8 r2. r8 | | %{ bar 2: %} g'8 r4 c'4 g'8 r4 | | %{ bar 3: %} d'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 r4 e'2 g'8 | | %{ bar 7: %} r4 f'4 r2 | | %{ bar 8: %} g'8 r4 g'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 r4 a'2 g'8 | | %{ bar 12: %} r4 b'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 r4 c''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XWe" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c'4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "1" c'4 | | %{ bar 3: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "1" c'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "1" c'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XWf" { g'8 r4 d''2 r8 | | %{ bar 2: %} g'8 c'4 r4 g'8 c'4 | | %{ bar 3: %} c'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 c'4 d'2 g'8 | | %{ bar 7: %} c'4 e'4 r2 | | %{ bar 8: %} g'8 c'4 f'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 c'4 g'2 g'8 | | %{ bar 12: %} c'4 a'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 c'4 b'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XXW" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c'4  \note-mod "2" d''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "2" d'4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "2" d'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "2" d'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XXX" { g'8 c'4 c''2 r8 | | %{ bar 2: %} g'8 c'4 d''4 g'8 d'4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 d'4 c'2 g'8 | | %{ bar 7: %} d'4 d'4 r2 | | %{ bar 8: %} g'8 d'4 e'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 d'4 f'2 g'8 | | %{ bar 12: %} d'4 g'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 d'4 a'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XXY" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "2" d'4 | | %{ bar 3: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "3" e'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "3" e'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "3" e'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XXZ" { g'8 d'4 b'2 r8 | | %{ bar 2: %} g'8 d'4 c''4 g'8 d'4 | | %{ bar 3: %} d''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 e'4 r2 g'8 | | %{ bar 7: %} e'4 c'4 r2 | | %{ bar 8: %} g'8 e'4 d'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 e'4 e'2 g'8 | | %{ bar 12: %} e'4 f'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 e'4 g'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XXa" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "3" e'4  \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "3" e'4 | | %{ bar 3: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "4" f'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "4" f'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XXb" { g'8 e'4 a'2 r8 | | %{ bar 2: %} g'8 e'4 b'4 g'8 e'4 | | %{ bar 3: %} c''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 e'4 d''2 g'8 | | %{ bar 7: %} f'4 r2. | | %{ bar 8: %} g'8 f'4 c'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 f'4 d'2 g'8 | | %{ bar 12: %} f'4 e'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 f'4 f'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XXc" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "4" f'4  \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "4" f'4 | | %{ bar 3: %}
 \note-mod "7" b'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "4" f'4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "5" g'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XXd" { g'8 f'4 g'2 r8 | | %{ bar 2: %} g'8 f'4 a'4 g'8 f'4 | | %{ bar 3: %} b'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 f'4 c''2 g'8 | | %{ bar 7: %} f'4 d''4 r2 | | %{ bar 8: %} g'8 g'4 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 g'4 c'2 g'8 | | %{ bar 12: %} g'4 d'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 g'4 e'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XXe" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4  \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "5" g'4 | | %{ bar 3: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "6" a'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "6" a'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XXf" { g'8 g'4 f'2 r8 | | %{ bar 2: %} g'8 g'4 g'4 g'8 g'4 | | %{ bar 3: %} a'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 g'4 b'2 g'8 | | %{ bar 7: %} g'4 c''4 r2 | | %{ bar 8: %} g'8 g'4 d''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 a'4 r2 g'8 | | %{ bar 12: %} a'4 c'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 a'4 d'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XYW" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "6" a'4  \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "6" a'4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "6" a'4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "6" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "7" b'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XYX" { g'8 a'4 e'2 r8 | | %{ bar 2: %} g'8 a'4 f'4 g'8 a'4 | | %{ bar 3: %} g'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 a'4 a'2 g'8 | | %{ bar 7: %} a'4 b'4 r2 | | %{ bar 8: %} g'8 a'4 c''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 a'4 d''2 g'8 | | %{ bar 12: %} b'4 r2. | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 b'4 c'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XYY" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "7" b'4  \note-mod "3" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "7" b'4 | | %{ bar 3: %}
 \note-mod "4" f'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "7" b'4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "7" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "7" b'4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XYZ" { g'8 b'4 d'2 r8 | | %{ bar 2: %} g'8 b'4 e'4 g'8 b'4 | | %{ bar 3: %} f'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 b'4 g'2 g'8 | | %{ bar 7: %} b'4 a'4 r2 | | %{ bar 8: %} g'8 b'4 b'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 b'4 c''2 g'8 | | %{ bar 12: %} b'4 d''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 c''4 r2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XYa" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c''4^.  \note-mod "2" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "1" c''4^. | | %{ bar 3: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "1" c''4^.
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XYb" { g'8 c''4 c'2 r8 | | %{ bar 2: %} g'8 c''4 d'4 g'8 c''4 | | %{ bar 3: %} e'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 c''4 f'2 g'8 | | %{ bar 7: %} c''4 g'4 r2 | | %{ bar 8: %} g'8 c''4 a'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 c''4 b'2 g'8 | | %{ bar 12: %} c''4 c''4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 c''4 d''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XYc" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d''4^.  \note-mod "1" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 \note-mod "2" d''4^. | | %{ bar 3: %}
 \note-mod "2" d'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 7: %}
 \note-mod "2" d''4^.
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
| | %{ bar 12: %}
 \note-mod "2" d''4^.
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XYd" { g'8 d''4 r2 r8 | | %{ bar 2: %} g'8 d''4 c'4 g'8 d''4 | | %{ bar 3: %} d'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} g'8 d''4 e'2 g'8 | | %{ bar 7: %} d''4 f'4 r2 | | %{ bar 8: %} g'8 d''4 g'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} g'8 d''4 a'2 g'8 | | %{ bar 12: %} d''4 b'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} g'8 d''4 c''2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XYe" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]   \note-mod "2" d''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "0" r4 | | %{ bar 3: %}
 \note-mod "1" c'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "6" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XYf" { g'8 d''4 d''2 r8 | | %{ bar 2: %} a'8 r2 a'8 r4 | | %{ bar 3: %} c'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} a'8 r4 d'2 a'8 | | %{ bar 7: %} r4 e'4 r2 | | %{ bar 8: %} a'8 r4 f'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} a'8 r4 g'2 a'8 | | %{ bar 12: %} r4 a'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} a'8 r4 b'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XZW" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "0" r4  \note-mod "2" d''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "1" c'4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 7: %}
 \note-mod "1" c'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 12: %}
 \note-mod "1" c'4
 \note-mod "5" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XZX" { a'8 r4 c''2 r8 | | %{ bar 2: %} a'8 r4 d''4 a'8 c'4 | | %{ bar 3: %} R1 | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} a'8 c'4 c'2 a'8 | | %{ bar 7: %} c'4 d'4 r2 | | %{ bar 8: %} a'8 c'4 e'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} a'8 c'4 f'2 a'8 | | %{ bar 12: %} c'4 g'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} a'8 c'4 a'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XZY" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "1" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "1" c'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "1" c'4 | | %{ bar 3: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "2" d'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 7: %}
 \note-mod "2" d'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 12: %}
 \note-mod "2" d'4
 \note-mod "4" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XZZ" { a'8 c'4 b'2 r8 | | %{ bar 2: %} a'8 c'4 c''4 a'8 c'4 | | %{ bar 3: %} d''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} a'8 d'4 r2 a'8 | | %{ bar 7: %} d'4 c'4 r2 | | %{ bar 8: %} a'8 d'4 d'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} a'8 d'4 e'2 a'8 | | %{ bar 12: %} d'4 f'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} a'8 d'4 g'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XZa" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "2" d'4  \note-mod "7" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "2" d'4 | | %{ bar 3: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "2" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 7: %}
 \note-mod "3" e'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 12: %}
 \note-mod "3" e'4
 \note-mod "3" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XZb" { a'8 d'4 a'2 r8 | | %{ bar 2: %} a'8 d'4 b'4 a'8 d'4 | | %{ bar 3: %} c''4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} a'8 d'4 d''2 a'8 | | %{ bar 7: %} e'4 r2. | | %{ bar 8: %} a'8 e'4 c'2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} a'8 e'4 d'2 a'8 | | %{ bar 12: %} e'4 e'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} a'8 e'4 f'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XZc" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "3" e'4  \note-mod "6" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "3" e'4 | | %{ bar 3: %}
 \note-mod "7" b'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "3" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 7: %}
 \note-mod "3" e'4
 \note-mod "2" d''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "4" f'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 12: %}
 \note-mod "4" f'4
 \note-mod "2" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XZd" { a'8 e'4 g'2 r8 | | %{ bar 2: %} a'8 e'4 a'4 a'8 e'4 | | %{ bar 3: %} b'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} a'8 e'4 c''2 a'8 | | %{ bar 7: %} e'4 d''4 r2 | | %{ bar 8: %} a'8 f'4 r2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} a'8 f'4 c'2 a'8 | | %{ bar 12: %} f'4 d'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} a'8 f'4 e'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XZe" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "4" f'4  \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "4" f'4 | | %{ bar 3: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
 ~  \note-mod "–" b'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 7: %}
 \note-mod "4" f'4
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "4" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
 ~  \note-mod "–" d''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 9: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "0" r4  \note-mod "–" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 12: %}
 \note-mod "5" g'4
 \note-mod "1" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 15: %}
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
    \new Staff { \new Voice="XZf" { a'8 f'4 f'2 r8 | | %{ bar 2: %} a'8 f'4 g'4 a'8 f'4 | | %{ bar 3: %} a'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} a'8 f'4 b'2 a'8 | | %{ bar 7: %} f'4 c''4 r2 | | %{ bar 8: %} a'8 f'4 d''2 r8 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} a'8 g'4 r2 a'8 | | %{ bar 12: %} g'4 c'4 r2 | | %{ bar 13: %} R1 | | %{ bar 14: %} a'8 g'4 d'2 r8 | | %{ bar 15: %} r1 | } }
% === END MIDI STAFF ===

>>
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
    { \new Voice="XaW" {
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
     \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4  \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
 \note-mod "5" g'4 | | %{ bar 3: %}
 \note-mod "5" g'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]   \note-mod "5" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[]
| | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %}
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
    \new Staff { \new Voice="XaX" { a'8 g'4 e'2 r8 | | %{ bar 2: %} a'8 g'4 f'4 a'8 g'4 | | %{ bar 3: %} g'4 r2. | | %{ bar 4: %} R1 | | %{ bar 5: %} R1 | | %{ bar 6: %} a'8 g'4 a'2 a'8 | | %{ bar 7: %} g'4 b'4 r2 | | %{ bar 8: %} r1 | } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
