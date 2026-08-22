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
subtitle=小星星
q2 - 0 0 q0 | q6 - 5 - q0 | 0 0 0 0 | q3 - q1 - 7 | - 1' - 2' | - 0 0 0 | q2 - 2 - q0 | 1 - 0 0 | 0 0 0 0 | 0 0 0 0 |
q1 - 1 - q0 | 5 - 5 0 | 4 - 4 - | 3 - 3 0 | q2 - 2 - q0 | 1 - 0 0 | 0 0 0 0 | 0 0 0 0 |
q6 - 6 - q0 | 5 - - 0 | q4 - q3 - q7 q0 | - q1' - q2' - | q2 - q2 - q1 q0 | 0 0 0 0 | 0 0 0 0 |
q5 - 5 - q0 | 4 - 4 0 | 3 - 3 - | 2 - - 0 | q3 - 3 - q0 | 2 - 0 0 | 0 0 0 0 | 0 0 0 0 |
q3 - 3 - q0 | 2 - - - | q5 - q4 - q6 q0 | - q7 - q1' - | q2' 0 0 0 q0 | q3 - q2 - q1 q0 | 0 0 0 0 | 0 0 0 0 |
q1 - 1 - q0 | 5 - 5 0 | 6 - 6 - | 5 - - 0 | q4 - 4 - q0 | 3 - 0 0 | 0 0 0 0 | 0 0 0 0 |
q4 - 4 - q0 | 3 - - - | q6 - q5 - q7 q0 | - q1' - q2' - | q4 - q3 - q2 q0 | 0 0 0 0 | 0 0 0 0 |
q1' - 1' - q0 | 5 - - 0 | 1' 6 - 1' | 6 - 1' 5 | - - - - | 1' 4 - 1' | 4 - 1' 3 | - - q1. 0 s0 | 0 0 0 0 | 0 0 0 0 |
q1' q1' 5 1' q5 q0 | 1' q5 - - q0 | - 0 0 0 | q1' q1' 1' 1' 7 | 1' 1' 1' 2' | q1' 0 0 0 q0 | 0 0 0 0 | 0 0 0 0 |
q5 - q5 - 4 | - - 0 0 | 1' 3 - 1' | 3 2 - - | - - 0 0 | 1' 5 - 1' | 5 - 1' 6 | - - q1. 0 s0 | 0 0 0 0 | 0 0 0 0 |
q1' q1' 5 1' q5 q0 | 1' q5 - - q0 | - 0 0 0 | q1' q1' 1' 1' 7 | 1' 1' 1' 2' | q1' 0 0 0 q0 | 0 0 0 0 | 0 0 0 0 |
q1 - q1 - 5 | - - 0 0 | 1' 6 - 1' | 6 - 1' 5 | - - - - | 1' 4 - 1' | 4 - 1' 3 | - - q1. 0 s0 | 0 0 0 0 | 0 0 0 0 |
q1' q1' 5 1' q5 q0 | 1' q5 - - q0 | - 0 0 0 | q1' q1' 1' 1' 7 | 1' 1' 1' 2' | q1' 0 0 0 q0 | 0 0 0 0 | 0 0 0 0 |
q2 - q2 - 1 | - - - - | - 0 0 0 | 1' 6 - 1' | 6 - 1' 5 | - - - - | 1' 4 - 1' | 4 - 1' 3 | - - q1. 0 s0 | 0 0 0 0 | 0 0 0 0 |
q1' q1' 5 1' q5 q0 | 1' q5 - - q0 | - 0 0 0 | q1' q1' 1' 1' 7 | 1' 1' 1' 2' | q1' 0 0 0 q0 | 0 0 0 0 | 0 0 0 0 |
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
     \time 4/4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  ~  \note-mod "–" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "7" b'4
\=JianpuTie(  ~ | | %{ bar 5: %}
 \note-mod "7" b'4 \=JianpuTie)
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d''4^.
\=JianpuTie(  ~ | | %{ bar 6: %}
 \note-mod "2" d''4^. \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 8: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 12: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "5" g'4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 13: %}
 \note-mod "4" f'4
 ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 14: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "3" e'4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 15: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 16: %}
 \note-mod "1" c'4
 ~  \note-mod "–" c'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 17: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 19: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  ~  \note-mod "–" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 20: %}
 \note-mod "5" g'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 21: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 22: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[]
 ~  \note-mod "–" d''4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 23: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 24: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 25: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 26: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 27: %}
 \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "4" f'4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 28: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 29: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 31: %}
 \note-mod "2" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 32: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 33: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 34: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 35: %}
 \note-mod "2" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~  \note-mod "–" d'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 36: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[]
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 37: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
]  ~  \note-mod "–" b'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[]
 ~  \note-mod "–" c''4 | | %{ bar 38: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 39: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
]  ~  \note-mod "–" e'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 40: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 41: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 42: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
 ~  \note-mod "–" c'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 43: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "5" g'4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 44: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 45: %}
 \note-mod "5" g'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 46: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 47: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 48: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 49: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 50: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 51: %}
 \note-mod "3" e'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" e'4
 ~  \note-mod "–" e'4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 52: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
]  ~  \note-mod "–" a'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 53: %}
 \note-mod "–" r4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[]
 ~  \note-mod "–" d''4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 54: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
]  ~  \note-mod "–" f'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[]
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 55: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 56: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 57: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]  ~  \note-mod "–" c''4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c''4^.
 ~  \note-mod "–" c''4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 58: %}
 \note-mod "5" g'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4  \note-mod "0" r4 | | %{ bar 59: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "1" c''4^. | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 60: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 61: %}
 \note-mod "5" g'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4 | | %{ bar 62: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "1" c''4^. | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 63: %}
 \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 64: %}
 \note-mod "3" e'4 \=JianpuTie)
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 65: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 66: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 67: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "5" g'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 68: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 69: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 70: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "7" b'4 | | %{ bar 71: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "2" d''4^. | | %{ bar 72: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 73: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 74: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 75: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[]
 ~  \note-mod "–" g'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 76: %}
 \note-mod "4" f'4 \=JianpuTie)
 ~  \note-mod "–" f'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 77: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "1" c''4^. | | %{ bar 78: %}
 \note-mod "3" e'4
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "2" d'4
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" d'4
 ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 79: %}
 \note-mod "2" d'4 \=JianpuTie)
 ~  \note-mod "–" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 80: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "1" c''4^. | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 81: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4  \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 82: %}
 \note-mod "6" a'4 \=JianpuTie)
 ~  \note-mod "–" a'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 83: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 84: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 85: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "5" g'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 86: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 87: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 88: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "7" b'4 | | %{ bar 89: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "2" d''4^. | | %{ bar 90: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 91: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 92: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 93: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 ~  \note-mod "–" c'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 94: %}
 \note-mod "5" g'4 \=JianpuTie)
 ~  \note-mod "–" g'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 95: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "1" c''4^. | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 96: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 97: %}
 \note-mod "5" g'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4 | | %{ bar 98: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "1" c''4^. | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 99: %}
 \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 100: %}
 \note-mod "3" e'4 \=JianpuTie)
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 101: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 102: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 103: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "5" g'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 104: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 105: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 106: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "7" b'4 | | %{ bar 107: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "2" d''4^. | | %{ bar 108: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 109: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 111: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]  ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[]
 ~  \note-mod "–" d'4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "1" c'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 112: %}
 \note-mod "1" c'4 \=JianpuTie)
\=JianpuTie(  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" c'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" c'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" c'4
 ~ | | %{ bar 113: %}
 \note-mod "1" c'4 \=JianpuTie)
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 114: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "1" c''4^. | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 115: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "5" g'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 116: %}
 \note-mod "5" g'4 \=JianpuTie)
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4 | | %{ bar 117: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "1" c''4^. | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 118: %}
 \note-mod "4" f'4
 ~  \note-mod "–" f'4  \note-mod "1" c''4^. \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "3" e'4
\=JianpuTie(  ~ | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 119: %}
 \note-mod "3" e'4 \=JianpuTie)
 ~  \note-mod "–" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
]   \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c'16[]
| | %{ bar 120: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 121: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 122: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "5" g'4  \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 123: %}
 \note-mod "1" c''4^.
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
]  ~ \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "–" g'4
 ~  \note-mod "–" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 124: %}
 \note-mod "–" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 125: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "7" b'4 | | %{ bar 126: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "2" d''4^. | | %{ bar 127: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 128: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 129: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \bar "|." } }
% === END JIANPU STAFF ===

>>
\header{
subtitle="小星星"
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
    \new Staff { \new Voice="X" { \time 4/4 d'8  ~ d'4 r2 r8 | | %{ bar 2: %} a'8  ~ a'4 g'2 r8 | | %{ bar 3: %} R1 | | %{ bar 4: %} e'8  ~ e'4 c'8  ~ c'4 b'4  ~ | | %{ bar 5: %} b'4 c''2 d''4  ~ | | %{ bar 6: %} d''4 r2. | | %{ bar 7: %} d'8  ~ d'4 d'2 r8 | | %{ bar 8: %} c'2 r2 | | %{ bar 9: %} R1 | | %{ bar 10: %} R1 | | %{ bar 11: %} c'8  ~ c'4 c'2 r8 | | %{ bar 12: %} g'2 g'4 r4 | | %{ bar 13: %} f'2 f'2 | | %{ bar 14: %} e'2 e'4 r4 | | %{ bar 15: %} d'8  ~ d'4 d'2 r8 | | %{ bar 16: %} c'2 r2 | | %{ bar 17: %} R1 | | %{ bar 18: %} R1 | | %{ bar 19: %} a'8  ~ a'4 a'2 r8 | | %{ bar 20: %} g'2. r4 | | %{ bar 21: %} f'8  ~ f'4 e'8  ~ e'4 b'8 r8 | | %{ bar 22: %} r4 c''8  ~ c''4 d''8  ~ d''4 | | %{ bar 23: %} d'8  ~ d'4 d'8  ~ d'4 c'8 r8 | | %{ bar 24: %} R1 | | %{ bar 25: %} R1 | | %{ bar 26: %} g'8  ~ g'4 g'2 r8 | | %{ bar 27: %} f'2 f'4 r4 | | %{ bar 28: %} e'2 e'2 | | %{ bar 29: %} d'2. r4 | | %{ bar 30: %} e'8  ~ e'4 e'2 r8 | | %{ bar 31: %} d'2 r2 | | %{ bar 32: %} R1 | | %{ bar 33: %} R1 | | %{ bar 34: %} e'8  ~ e'4 e'2 r8 | | %{ bar 35: %} d'1 | | %{ bar 36: %} g'8  ~ g'4 f'8  ~ f'4 a'8 r8 | | %{ bar 37: %} r4 b'8  ~ b'4 c''8  ~ c''4 | | %{ bar 38: %} d''8 r2. r8 | | %{ bar 39: %} e'8  ~ e'4 d'8  ~ d'4 c'8 r8 | | %{ bar 40: %} R1 | | %{ bar 41: %} R1 | | %{ bar 42: %} c'8  ~ c'4 c'2 r8 | | %{ bar 43: %} g'2 g'4 r4 | | %{ bar 44: %} a'2 a'2 | | %{ bar 45: %} g'2. r4 | | %{ bar 46: %} f'8  ~ f'4 f'2 r8 | | %{ bar 47: %} e'2 r2 | | %{ bar 48: %} R1 | | %{ bar 49: %} R1 | | %{ bar 50: %} f'8  ~ f'4 f'2 r8 | | %{ bar 51: %} e'1 | | %{ bar 52: %} a'8  ~ a'4 g'8  ~ g'4 b'8 r8 | | %{ bar 53: %} r4 c''8  ~ c''4 d''8  ~ d''4 | | %{ bar 54: %} f'8  ~ f'4 e'8  ~ e'4 d'8 r8 | | %{ bar 55: %} R1 | | %{ bar 56: %} R1 | | %{ bar 57: %} c''8  ~ c''4 c''2 r8 | | %{ bar 58: %} g'2. r4 | | %{ bar 59: %} c''4 a'2 c''4 | | %{ bar 60: %} a'2 c''4 g'4  ~ | | %{ bar 61: %} g'1 | | %{ bar 62: %} c''4 f'2 c''4 | | %{ bar 63: %} f'2 c''4 e'4  ~ | | %{ bar 64: %} e'2 c'8. r4 r16 | | %{ bar 65: %} R1 | | %{ bar 66: %} R1 | | %{ bar 67: %} c''8 c''8 g'4 c''4 g'8 r8 | | %{ bar 68: %} c''4 g'8  ~ g'2 r8 | | %{ bar 69: %} R1 | | %{ bar 70: %} c''8 c''8 c''4 c''4 b'4 | | %{ bar 71: %} c''4 c''4 c''4 d''4 | | %{ bar 72: %} c''8 r2. r8 | | %{ bar 73: %} R1 | | %{ bar 74: %} R1 | | %{ bar 75: %} g'8  ~ g'4 g'8  ~ g'4 f'4  ~ | | %{ bar 76: %} f'2 r2 | | %{ bar 77: %} c''4 e'2 c''4 | | %{ bar 78: %} e'4 d'2.  ~ | | %{ bar 79: %} d'2 r2 | | %{ bar 80: %} c''4 g'2 c''4 | | %{ bar 81: %} g'2 c''4 a'4  ~ | | %{ bar 82: %} a'2 c'8. r4 r16 | | %{ bar 83: %} R1 | | %{ bar 84: %} R1 | | %{ bar 85: %} c''8 c''8 g'4 c''4 g'8 r8 | | %{ bar 86: %} c''4 g'8  ~ g'2 r8 | | %{ bar 87: %} R1 | | %{ bar 88: %} c''8 c''8 c''4 c''4 b'4 | | %{ bar 89: %} c''4 c''4 c''4 d''4 | | %{ bar 90: %} c''8 r2. r8 | | %{ bar 91: %} R1 | | %{ bar 92: %} R1 | | %{ bar 93: %} c'8  ~ c'4 c'8  ~ c'4 g'4  ~ | | %{ bar 94: %} g'2 r2 | | %{ bar 95: %} c''4 a'2 c''4 | | %{ bar 96: %} a'2 c''4 g'4  ~ | | %{ bar 97: %} g'1 | | %{ bar 98: %} c''4 f'2 c''4 | | %{ bar 99: %} f'2 c''4 e'4  ~ | | %{ bar 100: %} e'2 c'8. r4 r16 | | %{ bar 101: %} R1 | | %{ bar 102: %} R1 | | %{ bar 103: %} c''8 c''8 g'4 c''4 g'8 r8 | | %{ bar 104: %} c''4 g'8  ~ g'2 r8 | | %{ bar 105: %} R1 | | %{ bar 106: %} c''8 c''8 c''4 c''4 b'4 | | %{ bar 107: %} c''4 c''4 c''4 d''4 | | %{ bar 108: %} c''8 r2. r8 | | %{ bar 109: %} R1 | | %{ bar 110: %} R1 | | %{ bar 111: %} d'8  ~ d'4 d'8  ~ d'4 c'4  ~ | | %{ bar 112: %} c'1  ~ | | %{ bar 113: %} c'4 r2. | | %{ bar 114: %} c''4 a'2 c''4 | | %{ bar 115: %} a'2 c''4 g'4  ~ | | %{ bar 116: %} g'1 | | %{ bar 117: %} c''4 f'2 c''4 | | %{ bar 118: %} f'2 c''4 e'4  ~ | | %{ bar 119: %} e'2 c'8. r4 r16 | | %{ bar 120: %} R1 | | %{ bar 121: %} R1 | | %{ bar 122: %} c''8 c''8 g'4 c''4 g'8 r8 | | %{ bar 123: %} c''4 g'8  ~ g'2 r8 | | %{ bar 124: %} R1 | | %{ bar 125: %} c''8 c''8 c''4 c''4 b'4 | | %{ bar 126: %} c''4 c''4 c''4 d''4 | | %{ bar 127: %} c''8 r2. r8 | | %{ bar 128: %} R1 | | %{ bar 129: %} r1 | } }
% === END MIDI STAFF ===

>>
\header{
subtitle="小星星"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
