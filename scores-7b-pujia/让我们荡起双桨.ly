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
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
1. 0 0 q0
0 q2 0 0 q0 | 0 0 0 0 |
3 - 0 0 | 0 0 0 0 |
6 0 0 0
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
     \time 4/4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 3: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 6: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 7: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 8: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 9: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 11: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 12: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 13: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 14: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 15: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 16: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 17: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 18: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 19: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 20: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 21: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 22: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 23: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 24: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 25: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 26: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 27: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 28: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 29: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 30: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 31: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 32: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 33: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 34: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 35: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 36: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 37: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 38: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 39: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 40: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 41: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 42: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 43: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 44: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 45: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 46: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 47: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 48: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 49: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 50: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 51: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 52: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 53: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 54: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 55: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 56: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 57: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 58: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 59: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 60: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 61: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 62: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 63: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 64: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 65: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 66: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 67: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 68: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 69: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 70: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 71: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 72: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 73: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 74: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 75: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 76: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 77: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 78: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 79: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 80: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 81: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 82: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 83: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 84: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 85: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 86: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 87: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 88: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 89: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 90: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 91: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 92: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 93: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 94: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 95: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 96: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 97: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 98: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 99: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 100: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 101: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 102: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 103: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 104: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 105: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 106: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 107: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 108: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 109: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 110: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 111: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 112: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 113: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 114: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 115: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 116: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 117: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 118: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 119: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 120: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 121: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 122: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 123: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 124: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 125: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 126: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 127: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 128: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 129: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 130: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 131: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 132: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 133: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 134: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 135: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 136: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 137: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 138: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 139: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 140: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 141: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 142: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 143: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 144: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 145: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 146: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 147: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 148: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 149: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 150: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 151: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 152: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 153: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 154: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 155: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 156: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 157: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 158: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 159: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 160: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 161: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 162: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 163: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 164: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 165: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 166: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 167: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 168: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 169: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 170: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 171: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 172: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 173: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 174: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 175: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 176: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 177: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 178: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 179: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 180: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 181: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 182: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 183: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 184: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 185: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 186: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 187: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 188: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 189: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 190: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 191: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 192: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 193: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 194: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 195: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 196: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 197: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 198: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 199: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 200: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 201: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 202: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 203: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 204: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 205: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 206: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 207: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 208: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 209: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 210: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 211: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 212: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 213: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 214: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 215: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 216: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 217: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 218: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 219: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 220: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 221: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 222: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 223: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 224: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 225: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 226: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 227: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 228: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 229: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 230: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 231: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 232: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 233: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 234: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 235: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 236: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 237: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 238: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 239: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 240: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 241: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 242: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 243: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 244: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 245: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 246: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 247: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 248: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 249: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 250: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 251: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 252: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 253: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 254: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 255: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 256: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 257: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 258: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 259: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 260: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 261: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 262: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 263: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 264: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 265: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 266: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 267: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 268: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 269: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 270: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 271: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 272: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 273: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 274: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 275: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 276: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 277: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 278: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 279: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 280: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 281: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 282: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 283: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 284: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 285: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 286: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 287: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 288: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 289: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 290: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 291: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 292: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 293: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 294: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 295: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 296: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 297: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 298: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 299: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 300: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 301: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 302: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 303: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 304: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 305: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 306: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 307: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 308: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 309: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 310: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 311: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 312: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 313: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 314: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 315: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 316: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 317: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 318: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 319: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 320: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 321: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 322: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 323: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 324: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 325: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 326: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 327: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 328: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 329: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 330: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 331: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 332: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 333: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 334: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 335: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 336: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 337: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 338: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 339: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 340: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 341: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 342: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 343: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 344: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 345: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 346: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 347: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 348: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 349: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 350: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 351: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 352: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 353: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 354: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 355: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 356: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 357: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 358: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 359: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 360: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 361: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 362: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 363: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 364: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 365: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 366: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 367: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 368: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 369: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 370: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 371: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 372: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 373: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 374: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 375: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 376: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 377: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 378: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 379: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 380: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 381: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 382: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 383: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 384: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 385: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 386: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 387: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 388: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 389: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 390: %}
 \note-mod "1" c'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 391: %}
 \note-mod "0" r4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 392: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 393: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 394: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 395: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \bar "|." } }
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
    \new Staff { \new Voice="X" { \time 4/4 r4 d'8 r2 r8 | | %{ bar 2: %} R1 | | %{ bar 3: %} e'2 r2 | | %{ bar 4: %} R1 | | %{ bar 5: %} a'4 r2. | %{ bar 6: %} c'4. r2 r8 | %{ bar 7: %} r4 d'8 r2 r8 | | %{ bar 8: %} R1 | | %{ bar 9: %} e'2 r2 | | %{ bar 10: %} R1 | | %{ bar 11: %} a'4 r2. | %{ bar 12: %} c'4. r2 r8 | %{ bar 13: %} r4 d'8 r2 r8 | | %{ bar 14: %} R1 | | %{ bar 15: %} e'2 r2 | | %{ bar 16: %} R1 | | %{ bar 17: %} a'4 r2. | %{ bar 18: %} c'4. r2 r8 | %{ bar 19: %} r4 d'8 r2 r8 | | %{ bar 20: %} R1 | | %{ bar 21: %} e'2 r2 | | %{ bar 22: %} R1 | | %{ bar 23: %} a'4 r2. | %{ bar 24: %} c'4. r2 r8 | %{ bar 25: %} r4 d'8 r2 r8 | | %{ bar 26: %} R1 | | %{ bar 27: %} e'2 r2 | | %{ bar 28: %} R1 | | %{ bar 29: %} a'4 r2. | %{ bar 30: %} c'4. r2 r8 | %{ bar 31: %} r4 d'8 r2 r8 | | %{ bar 32: %} R1 | | %{ bar 33: %} e'2 r2 | | %{ bar 34: %} R1 | | %{ bar 35: %} a'4 r2. | %{ bar 36: %} c'4. r2 r8 | %{ bar 37: %} r4 d'8 r2 r8 | | %{ bar 38: %} R1 | | %{ bar 39: %} e'2 r2 | | %{ bar 40: %} R1 | | %{ bar 41: %} a'4 r2. | %{ bar 42: %} c'4. r2 r8 | %{ bar 43: %} r4 d'8 r2 r8 | | %{ bar 44: %} R1 | | %{ bar 45: %} e'2 r2 | | %{ bar 46: %} R1 | | %{ bar 47: %} a'4 r2. | %{ bar 48: %} c'4. r2 r8 | %{ bar 49: %} r4 d'8 r2 r8 | | %{ bar 50: %} R1 | | %{ bar 51: %} e'2 r2 | | %{ bar 52: %} R1 | | %{ bar 53: %} a'4 r2. | %{ bar 54: %} c'4. r2 r8 | %{ bar 55: %} r4 d'8 r2 r8 | | %{ bar 56: %} R1 | | %{ bar 57: %} e'2 r2 | | %{ bar 58: %} R1 | | %{ bar 59: %} a'4 r2. | %{ bar 60: %} c'4. r2 r8 | %{ bar 61: %} r4 d'8 r2 r8 | | %{ bar 62: %} R1 | | %{ bar 63: %} e'2 r2 | | %{ bar 64: %} R1 | | %{ bar 65: %} a'4 r2. | %{ bar 66: %} c'4. r2 r8 | %{ bar 67: %} r4 d'8 r2 r8 | | %{ bar 68: %} R1 | | %{ bar 69: %} e'2 r2 | | %{ bar 70: %} R1 | | %{ bar 71: %} a'4 r2. | %{ bar 72: %} c'4. r2 r8 | %{ bar 73: %} r4 d'8 r2 r8 | | %{ bar 74: %} R1 | | %{ bar 75: %} e'2 r2 | | %{ bar 76: %} R1 | | %{ bar 77: %} a'4 r2. | %{ bar 78: %} c'4. r2 r8 | %{ bar 79: %} r4 d'8 r2 r8 | | %{ bar 80: %} R1 | | %{ bar 81: %} e'2 r2 | | %{ bar 82: %} R1 | | %{ bar 83: %} a'4 r2. | %{ bar 84: %} c'4. r2 r8 | %{ bar 85: %} r4 d'8 r2 r8 | | %{ bar 86: %} R1 | | %{ bar 87: %} e'2 r2 | | %{ bar 88: %} R1 | | %{ bar 89: %} a'4 r2. | %{ bar 90: %} c'4. r2 r8 | %{ bar 91: %} r4 d'8 r2 r8 | | %{ bar 92: %} R1 | | %{ bar 93: %} e'2 r2 | | %{ bar 94: %} R1 | | %{ bar 95: %} a'4 r2. | %{ bar 96: %} c'4. r2 r8 | %{ bar 97: %} r4 d'8 r2 r8 | | %{ bar 98: %} R1 | | %{ bar 99: %} e'2 r2 | | %{ bar 100: %} R1 | | %{ bar 101: %} a'4 r2. | %{ bar 102: %} c'4. r2 r8 | %{ bar 103: %} r4 d'8 r2 r8 | | %{ bar 104: %} R1 | | %{ bar 105: %} e'2 r2 | | %{ bar 106: %} R1 | | %{ bar 107: %} a'4 r2. | %{ bar 108: %} c'4. r2 r8 | %{ bar 109: %} r4 d'8 r2 r8 | | %{ bar 110: %} R1 | | %{ bar 111: %} e'2 r2 | | %{ bar 112: %} R1 | | %{ bar 113: %} a'4 r2. | %{ bar 114: %} c'4. r2 r8 | %{ bar 115: %} r4 d'8 r2 r8 | | %{ bar 116: %} R1 | | %{ bar 117: %} e'2 r2 | | %{ bar 118: %} R1 | | %{ bar 119: %} a'4 r2. | %{ bar 120: %} c'4. r2 r8 | %{ bar 121: %} r4 d'8 r2 r8 | | %{ bar 122: %} R1 | | %{ bar 123: %} e'2 r2 | | %{ bar 124: %} R1 | | %{ bar 125: %} a'4 r2. | %{ bar 126: %} c'4. r2 r8 | %{ bar 127: %} r4 d'8 r2 r8 | | %{ bar 128: %} R1 | | %{ bar 129: %} e'2 r2 | | %{ bar 130: %} R1 | | %{ bar 131: %} a'4 r2. | %{ bar 132: %} c'4. r2 r8 | %{ bar 133: %} r4 d'8 r2 r8 | | %{ bar 134: %} R1 | | %{ bar 135: %} e'2 r2 | | %{ bar 136: %} R1 | | %{ bar 137: %} a'4 r2. | %{ bar 138: %} c'4. r2 r8 | %{ bar 139: %} r4 d'8 r2 r8 | | %{ bar 140: %} R1 | | %{ bar 141: %} e'2 r2 | | %{ bar 142: %} R1 | | %{ bar 143: %} a'4 r2. | %{ bar 144: %} c'4. r2 r8 | %{ bar 145: %} r4 d'8 r2 r8 | | %{ bar 146: %} R1 | | %{ bar 147: %} e'2 r2 | | %{ bar 148: %} R1 | | %{ bar 149: %} a'4 r2. | %{ bar 150: %} c'4. r2 r8 | %{ bar 151: %} r4 d'8 r2 r8 | | %{ bar 152: %} R1 | | %{ bar 153: %} e'2 r2 | | %{ bar 154: %} R1 | | %{ bar 155: %} a'4 r2. | %{ bar 156: %} c'4. r2 r8 | %{ bar 157: %} r4 d'8 r2 r8 | | %{ bar 158: %} R1 | | %{ bar 159: %} e'2 r2 | | %{ bar 160: %} R1 | | %{ bar 161: %} a'4 r2. | %{ bar 162: %} c'4. r2 r8 | %{ bar 163: %} r4 d'8 r2 r8 | | %{ bar 164: %} R1 | | %{ bar 165: %} e'2 r2 | | %{ bar 166: %} R1 | | %{ bar 167: %} a'4 r2. | %{ bar 168: %} c'4. r2 r8 | %{ bar 169: %} r4 d'8 r2 r8 | | %{ bar 170: %} R1 | | %{ bar 171: %} e'2 r2 | | %{ bar 172: %} R1 | | %{ bar 173: %} a'4 r2. | %{ bar 174: %} c'4. r2 r8 | %{ bar 175: %} r4 d'8 r2 r8 | | %{ bar 176: %} R1 | | %{ bar 177: %} e'2 r2 | | %{ bar 178: %} R1 | | %{ bar 179: %} a'4 r2. | %{ bar 180: %} c'4. r2 r8 | %{ bar 181: %} r4 d'8 r2 r8 | | %{ bar 182: %} R1 | | %{ bar 183: %} e'2 r2 | | %{ bar 184: %} R1 | | %{ bar 185: %} a'4 r2. | %{ bar 186: %} c'4. r2 r8 | %{ bar 187: %} r4 d'8 r2 r8 | | %{ bar 188: %} R1 | | %{ bar 189: %} e'2 r2 | | %{ bar 190: %} R1 | | %{ bar 191: %} a'4 r2. | %{ bar 192: %} c'4. r2 r8 | %{ bar 193: %} r4 d'8 r2 r8 | | %{ bar 194: %} R1 | | %{ bar 195: %} e'2 r2 | | %{ bar 196: %} R1 | | %{ bar 197: %} a'4 r2. | %{ bar 198: %} c'4. r2 r8 | %{ bar 199: %} r4 d'8 r2 r8 | | %{ bar 200: %} R1 | | %{ bar 201: %} e'2 r2 | | %{ bar 202: %} R1 | | %{ bar 203: %} a'4 r2. | %{ bar 204: %} c'4. r2 r8 | %{ bar 205: %} r4 d'8 r2 r8 | | %{ bar 206: %} R1 | | %{ bar 207: %} e'2 r2 | | %{ bar 208: %} R1 | | %{ bar 209: %} a'4 r2. | %{ bar 210: %} c'4. r2 r8 | %{ bar 211: %} r4 d'8 r2 r8 | | %{ bar 212: %} R1 | | %{ bar 213: %} e'2 r2 | | %{ bar 214: %} R1 | | %{ bar 215: %} a'4 r2. | %{ bar 216: %} c'4. r2 r8 | %{ bar 217: %} r4 d'8 r2 r8 | | %{ bar 218: %} R1 | | %{ bar 219: %} e'2 r2 | | %{ bar 220: %} R1 | | %{ bar 221: %} a'4 r2. | %{ bar 222: %} c'4. r2 r8 | %{ bar 223: %} r4 d'8 r2 r8 | | %{ bar 224: %} R1 | | %{ bar 225: %} e'2 r2 | | %{ bar 226: %} R1 | | %{ bar 227: %} a'4 r2. | %{ bar 228: %} c'4. r2 r8 | %{ bar 229: %} r4 d'8 r2 r8 | | %{ bar 230: %} R1 | | %{ bar 231: %} e'2 r2 | | %{ bar 232: %} R1 | | %{ bar 233: %} a'4 r2. | %{ bar 234: %} c'4. r2 r8 | %{ bar 235: %} r4 d'8 r2 r8 | | %{ bar 236: %} R1 | | %{ bar 237: %} e'2 r2 | | %{ bar 238: %} R1 | | %{ bar 239: %} a'4 r2. | %{ bar 240: %} c'4. r2 r8 | %{ bar 241: %} r4 d'8 r2 r8 | | %{ bar 242: %} R1 | | %{ bar 243: %} e'2 r2 | | %{ bar 244: %} R1 | | %{ bar 245: %} a'4 r2. | %{ bar 246: %} c'4. r2 r8 | %{ bar 247: %} r4 d'8 r2 r8 | | %{ bar 248: %} R1 | | %{ bar 249: %} e'2 r2 | | %{ bar 250: %} R1 | | %{ bar 251: %} a'4 r2. | %{ bar 252: %} c'4. r2 r8 | %{ bar 253: %} r4 d'8 r2 r8 | | %{ bar 254: %} R1 | | %{ bar 255: %} e'2 r2 | | %{ bar 256: %} R1 | | %{ bar 257: %} a'4 r2. | %{ bar 258: %} c'4. r2 r8 | %{ bar 259: %} r4 d'8 r2 r8 | | %{ bar 260: %} R1 | | %{ bar 261: %} e'2 r2 | | %{ bar 262: %} R1 | | %{ bar 263: %} a'4 r2. | %{ bar 264: %} c'4. r2 r8 | %{ bar 265: %} r4 d'8 r2 r8 | | %{ bar 266: %} R1 | | %{ bar 267: %} e'2 r2 | | %{ bar 268: %} R1 | | %{ bar 269: %} a'4 r2. | %{ bar 270: %} c'4. r2 r8 | %{ bar 271: %} r4 d'8 r2 r8 | | %{ bar 272: %} R1 | | %{ bar 273: %} e'2 r2 | | %{ bar 274: %} R1 | | %{ bar 275: %} a'4 r2. | %{ bar 276: %} c'4. r2 r8 | %{ bar 277: %} r4 d'8 r2 r8 | | %{ bar 278: %} R1 | | %{ bar 279: %} e'2 r2 | | %{ bar 280: %} R1 | | %{ bar 281: %} a'4 r2. | %{ bar 282: %} c'4. r2 r8 | %{ bar 283: %} r4 d'8 r2 r8 | | %{ bar 284: %} R1 | | %{ bar 285: %} e'2 r2 | | %{ bar 286: %} R1 | | %{ bar 287: %} a'4 r2. | %{ bar 288: %} c'4. r2 r8 | %{ bar 289: %} r4 d'8 r2 r8 | | %{ bar 290: %} R1 | | %{ bar 291: %} e'2 r2 | | %{ bar 292: %} R1 | | %{ bar 293: %} a'4 r2. | %{ bar 294: %} c'4. r2 r8 | %{ bar 295: %} r4 d'8 r2 r8 | | %{ bar 296: %} R1 | | %{ bar 297: %} e'2 r2 | | %{ bar 298: %} R1 | | %{ bar 299: %} a'4 r2. | %{ bar 300: %} c'4. r2 r8 | %{ bar 301: %} r4 d'8 r2 r8 | | %{ bar 302: %} R1 | | %{ bar 303: %} e'2 r2 | | %{ bar 304: %} R1 | | %{ bar 305: %} a'4 r2. | %{ bar 306: %} c'4. r2 r8 | %{ bar 307: %} r4 d'8 r2 r8 | | %{ bar 308: %} R1 | | %{ bar 309: %} e'2 r2 | | %{ bar 310: %} R1 | | %{ bar 311: %} a'4 r2. | %{ bar 312: %} c'4. r2 r8 | %{ bar 313: %} r4 d'8 r2 r8 | | %{ bar 314: %} R1 | | %{ bar 315: %} e'2 r2 | | %{ bar 316: %} R1 | | %{ bar 317: %} a'4 r2. | %{ bar 318: %} c'4. r2 r8 | %{ bar 319: %} r4 d'8 r2 r8 | | %{ bar 320: %} R1 | | %{ bar 321: %} e'2 r2 | | %{ bar 322: %} R1 | | %{ bar 323: %} a'4 r2. | %{ bar 324: %} c'4. r2 r8 | %{ bar 325: %} r4 d'8 r2 r8 | | %{ bar 326: %} R1 | | %{ bar 327: %} e'2 r2 | | %{ bar 328: %} R1 | | %{ bar 329: %} a'4 r2. | %{ bar 330: %} c'4. r2 r8 | %{ bar 331: %} r4 d'8 r2 r8 | | %{ bar 332: %} R1 | | %{ bar 333: %} e'2 r2 | | %{ bar 334: %} R1 | | %{ bar 335: %} a'4 r2. | %{ bar 336: %} c'4. r2 r8 | %{ bar 337: %} r4 d'8 r2 r8 | | %{ bar 338: %} R1 | | %{ bar 339: %} e'2 r2 | | %{ bar 340: %} R1 | | %{ bar 341: %} a'4 r2. | %{ bar 342: %} c'4. r2 r8 | %{ bar 343: %} r4 d'8 r2 r8 | | %{ bar 344: %} R1 | | %{ bar 345: %} e'2 r2 | | %{ bar 346: %} R1 | | %{ bar 347: %} a'4 r2. | %{ bar 348: %} c'4. r2 r8 | %{ bar 349: %} r4 d'8 r2 r8 | | %{ bar 350: %} R1 | | %{ bar 351: %} e'2 r2 | | %{ bar 352: %} R1 | | %{ bar 353: %} a'4 r2. | %{ bar 354: %} c'4. r2 r8 | %{ bar 355: %} r4 d'8 r2 r8 | | %{ bar 356: %} R1 | | %{ bar 357: %} e'2 r2 | | %{ bar 358: %} R1 | | %{ bar 359: %} a'4 r2. | %{ bar 360: %} c'4. r2 r8 | %{ bar 361: %} r4 d'8 r2 r8 | | %{ bar 362: %} R1 | | %{ bar 363: %} e'2 r2 | | %{ bar 364: %} R1 | | %{ bar 365: %} a'4 r2. | %{ bar 366: %} c'4. r2 r8 | %{ bar 367: %} r4 d'8 r2 r8 | | %{ bar 368: %} R1 | | %{ bar 369: %} e'2 r2 | | %{ bar 370: %} R1 | | %{ bar 371: %} a'4 r2. | %{ bar 372: %} c'4. r2 r8 | %{ bar 373: %} r4 d'8 r2 r8 | | %{ bar 374: %} R1 | | %{ bar 375: %} e'2 r2 | | %{ bar 376: %} R1 | | %{ bar 377: %} a'4 r2. | %{ bar 378: %} c'4. r2 r8 | %{ bar 379: %} r4 d'8 r2 r8 | | %{ bar 380: %} R1 | | %{ bar 381: %} e'2 r2 | | %{ bar 382: %} R1 | | %{ bar 383: %} a'4 r2. | %{ bar 384: %} c'4. r2 r8 | %{ bar 385: %} r4 d'8 r2 r8 | | %{ bar 386: %} R1 | | %{ bar 387: %} e'2 r2 | | %{ bar 388: %} R1 | | %{ bar 389: %} a'4 r2. | %{ bar 390: %} c'4. r2 r8 | %{ bar 391: %} r4 d'8 r2 r8 | | %{ bar 392: %} R1 | | %{ bar 393: %} e'2 r2 | | %{ bar 394: %} R1 | | %{ bar 395: %} a'4 r2. } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
