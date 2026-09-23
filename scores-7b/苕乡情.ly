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
6 - 0 0 | 0 0 0 0 |
6 - 0 0 | 0 0 0 0 |
6 - 0 0
6 1' q2 3 q0 | 0 0 0 0 |
q1 0 0 0 q0
6 0 1' 1' | 6 5 6 0
1' 7 6 5 | 6 0 0 0
1' 2' 4 5
1' 6 5 0
2 - 0 0 | 0 0 0 0 |
3 - 0 0 | 6 0 0 0 | 0 0 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
q4 q2' 0 0 0
6 0 0 0 | 0 0 0 0 |
q5 q1 7 0 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 6 - 0 0 | 0 0 0 0 |
6 0 0 0 | 0 0 0 0 |
q5 q1 7 0 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 2. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
6 - 0 0 | 1' 1' 0 0 |
q2 5 q1 7 0 | 0 0 0 0 |
1' 1' 1' 0
q4 q2' 0 0 0
3 - 0 0 | 0. 0 0 q0 |
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
     \time 4/4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0  \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 2: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 3: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 5: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 6: %}
 \note-mod "6" a'4
 \note-mod "1" c''4^. \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "3" e'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 7: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]   \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 9: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "1" c''4^.  \note-mod "1" c''4^. | | %{ bar 10: %}
 \note-mod "6" a'4
 \note-mod "5" g'4  \note-mod "6" a'4  \note-mod "0" r4 | %{ bar 11: %}
 \note-mod "1" c''4^.
 \note-mod "7" b'4  \note-mod "6" a'4  \note-mod "5" g'4 | | %{ bar 12: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 13: %}
 \note-mod "1" c''4^.
 \note-mod "2" d''4^.  \note-mod "4" f'4  \note-mod "5" g'4 | %{ bar 14: %}
 \note-mod "1" c''4^.
 \note-mod "6" a'4  \note-mod "5" g'4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 15: %}
 \note-mod "2" d'4
 ~  \note-mod "–" d'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 16: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 17: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 18: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 19: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 20: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 21: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 22: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 23: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 24: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | %{ bar 25: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 26: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 27: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 28: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 29: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 31: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 32: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 33: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 34: %}
 \note-mod "6" a'4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 35: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 36: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "7" b'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 37: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 38: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 39: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 40: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 41: %}
 \note-mod "2" d'4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 42: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 43: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 44: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 45: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 46: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 47: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 48: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 49: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 50: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 51: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 52: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 53: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 54: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 55: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 56: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 57: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 58: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 59: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 60: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 61: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 62: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 63: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 64: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 65: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 66: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 67: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 68: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 69: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 70: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 71: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 72: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 73: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 74: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 75: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 76: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 77: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 78: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 79: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 80: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 81: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 82: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 83: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 84: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 85: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 86: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 87: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 88: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 89: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 90: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 91: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 92: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 93: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 94: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 95: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 96: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 97: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 98: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 99: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 100: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 101: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 102: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 103: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 104: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 105: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 106: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 107: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 108: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 109: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 110: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 111: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 112: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 113: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 114: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 115: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 116: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 117: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 118: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 119: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 120: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 121: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 122: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 123: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 124: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 125: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 126: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 127: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 128: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 129: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 130: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 131: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 132: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 133: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 134: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 135: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 136: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 137: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 138: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 139: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 140: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 141: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 142: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 143: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 144: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 145: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 146: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 147: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 148: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 149: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 150: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 151: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 152: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 153: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 154: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 155: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 156: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 157: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 158: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 159: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 160: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 161: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 162: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 163: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 164: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 165: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 166: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 167: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 168: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 169: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 170: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 171: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 172: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 173: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 174: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 175: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 176: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 177: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 178: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 179: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 180: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 181: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 182: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 183: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 184: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 185: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 186: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 187: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 188: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 189: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 190: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 191: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 192: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 193: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 194: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 195: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 196: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 197: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 198: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 199: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 200: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 201: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 202: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 203: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 204: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 205: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 206: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 207: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 208: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 209: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 210: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 211: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 212: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 213: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 214: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 215: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 216: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 217: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 218: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 219: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 220: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 221: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 222: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 223: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 224: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 225: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 226: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 227: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 228: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 229: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 230: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 231: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 232: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 233: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 234: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 235: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 236: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 237: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 238: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 239: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 240: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 241: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 242: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 243: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 244: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 245: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 246: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 247: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 248: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 249: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 250: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 251: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 252: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 253: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 254: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 255: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 256: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 257: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 258: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 259: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 260: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 261: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 262: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 263: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 264: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 265: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 266: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 267: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 268: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 269: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 270: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 271: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 272: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 273: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 274: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 275: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 276: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 277: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 278: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 279: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 280: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 281: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 282: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 283: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 284: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 285: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 286: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 287: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 288: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 289: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 290: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 291: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 292: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 293: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 294: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 295: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 296: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 297: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 298: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 299: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 300: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 301: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 302: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 303: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 304: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 305: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 306: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 307: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 308: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 309: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 310: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 311: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 312: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 313: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 314: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 315: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 316: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 317: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 318: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 319: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 320: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 321: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 322: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 323: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 324: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 325: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 326: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 327: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 328: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 329: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 330: %}
 \note-mod "6" a'4
 ~  \note-mod "–" a'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 331: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 332: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
]   \note-mod "5" g'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[]
 \note-mod "7" b'4  \note-mod "0" r4 | | %{ bar 333: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 334: %}
 \note-mod "1" c''4^.
 \note-mod "1" c''4^.  \note-mod "1" c''4^.  \note-mod "0" r4 | %{ bar 335: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
 \note-mod "0" r4  \note-mod "0" r4  \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 336: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4  \note-mod "0" r4  \note-mod "0" r4 | | %{ bar 337: %}
 \note-mod "0" r4.
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
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
    \new Staff { \new Voice="X" { \time 4/4 a'2 r2 | | %{ bar 2: %} R1 | | %{ bar 3: %} a'2 r2 | | %{ bar 4: %} R1 | | %{ bar 5: %} a'2 r2 | %{ bar 6: %} a'4 c''4 d'8 e'4 r8 | | %{ bar 7: %} R1 | | %{ bar 8: %} c'8 r2. r8 | %{ bar 9: %} a'4 r4 c''4 c''4 | | %{ bar 10: %} a'4 g'4 a'4 r4 | %{ bar 11: %} c''4 b'4 a'4 g'4 | | %{ bar 12: %} a'4 r2. | %{ bar 13: %} c''4 d''4 f'4 g'4 | %{ bar 14: %} c''4 a'4 g'4 r4 | %{ bar 15: %} d'2 r2 | | %{ bar 16: %} R1 | | %{ bar 17: %} e'2 r2 | | %{ bar 18: %} a'4 r2. | | %{ bar 19: %} R1 | | %{ bar 20: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 21: %} R1 | | %{ bar 22: %} c''4 c''4 c''4 r4 | %{ bar 23: %} f'8 d''8 r2. | %{ bar 24: %} f'8 d''8 r2. | %{ bar 25: %} a'4 r2. | | %{ bar 26: %} R1 | | %{ bar 27: %} g'8 c'8 b'4 r2 | | %{ bar 28: %} R1 | | %{ bar 29: %} c''4 c''4 c''4 r4 | %{ bar 30: %} f'8 d''8 r2. | %{ bar 31: %} e'2 r2 | | %{ bar 32: %} a'2 r2 | | %{ bar 33: %} R1 | | %{ bar 34: %} a'4 r2. | | %{ bar 35: %} R1 | | %{ bar 36: %} g'8 c'8 b'4 r2 | | %{ bar 37: %} R1 | | %{ bar 38: %} c''4 c''4 c''4 r4 | %{ bar 39: %} f'8 d''8 r2. | %{ bar 40: %} e'2 r2 | | %{ bar 41: %} d'4. r2 r8 | | %{ bar 42: %} a'2 r2 | | %{ bar 43: %} c''4 c''4 r2 | | %{ bar 44: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 45: %} R1 | | %{ bar 46: %} c''4 c''4 c''4 r4 | %{ bar 47: %} f'8 d''8 r2. | %{ bar 48: %} e'2 r2 | | %{ bar 49: %} r4. r2 r8 | | %{ bar 50: %} a'2 r2 | | %{ bar 51: %} c''4 c''4 r2 | | %{ bar 52: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 53: %} R1 | | %{ bar 54: %} c''4 c''4 c''4 r4 | %{ bar 55: %} f'8 d''8 r2. | %{ bar 56: %} e'2 r2 | | %{ bar 57: %} r4. r2 r8 | | %{ bar 58: %} a'2 r2 | | %{ bar 59: %} c''4 c''4 r2 | | %{ bar 60: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 61: %} R1 | | %{ bar 62: %} c''4 c''4 c''4 r4 | %{ bar 63: %} f'8 d''8 r2. | %{ bar 64: %} e'2 r2 | | %{ bar 65: %} r4. r2 r8 | | %{ bar 66: %} a'2 r2 | | %{ bar 67: %} c''4 c''4 r2 | | %{ bar 68: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 69: %} R1 | | %{ bar 70: %} c''4 c''4 c''4 r4 | %{ bar 71: %} f'8 d''8 r2. | %{ bar 72: %} e'2 r2 | | %{ bar 73: %} r4. r2 r8 | | %{ bar 74: %} a'2 r2 | | %{ bar 75: %} c''4 c''4 r2 | | %{ bar 76: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 77: %} R1 | | %{ bar 78: %} c''4 c''4 c''4 r4 | %{ bar 79: %} f'8 d''8 r2. | %{ bar 80: %} e'2 r2 | | %{ bar 81: %} r4. r2 r8 | | %{ bar 82: %} a'2 r2 | | %{ bar 83: %} c''4 c''4 r2 | | %{ bar 84: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 85: %} R1 | | %{ bar 86: %} c''4 c''4 c''4 r4 | %{ bar 87: %} f'8 d''8 r2. | %{ bar 88: %} e'2 r2 | | %{ bar 89: %} r4. r2 r8 | | %{ bar 90: %} a'2 r2 | | %{ bar 91: %} c''4 c''4 r2 | | %{ bar 92: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 93: %} R1 | | %{ bar 94: %} c''4 c''4 c''4 r4 | %{ bar 95: %} f'8 d''8 r2. | %{ bar 96: %} e'2 r2 | | %{ bar 97: %} r4. r2 r8 | | %{ bar 98: %} a'2 r2 | | %{ bar 99: %} c''4 c''4 r2 | | %{ bar 100: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 101: %} R1 | | %{ bar 102: %} c''4 c''4 c''4 r4 | %{ bar 103: %} f'8 d''8 r2. | %{ bar 104: %} e'2 r2 | | %{ bar 105: %} r4. r2 r8 | | %{ bar 106: %} a'2 r2 | | %{ bar 107: %} c''4 c''4 r2 | | %{ bar 108: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 109: %} R1 | | %{ bar 110: %} c''4 c''4 c''4 r4 | %{ bar 111: %} f'8 d''8 r2. | %{ bar 112: %} e'2 r2 | | %{ bar 113: %} r4. r2 r8 | | %{ bar 114: %} a'2 r2 | | %{ bar 115: %} c''4 c''4 r2 | | %{ bar 116: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 117: %} R1 | | %{ bar 118: %} c''4 c''4 c''4 r4 | %{ bar 119: %} f'8 d''8 r2. | %{ bar 120: %} e'2 r2 | | %{ bar 121: %} r4. r2 r8 | | %{ bar 122: %} a'2 r2 | | %{ bar 123: %} c''4 c''4 r2 | | %{ bar 124: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 125: %} R1 | | %{ bar 126: %} c''4 c''4 c''4 r4 | %{ bar 127: %} f'8 d''8 r2. | %{ bar 128: %} e'2 r2 | | %{ bar 129: %} r4. r2 r8 | | %{ bar 130: %} a'2 r2 | | %{ bar 131: %} c''4 c''4 r2 | | %{ bar 132: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 133: %} R1 | | %{ bar 134: %} c''4 c''4 c''4 r4 | %{ bar 135: %} f'8 d''8 r2. | %{ bar 136: %} e'2 r2 | | %{ bar 137: %} r4. r2 r8 | | %{ bar 138: %} a'2 r2 | | %{ bar 139: %} c''4 c''4 r2 | | %{ bar 140: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 141: %} R1 | | %{ bar 142: %} c''4 c''4 c''4 r4 | %{ bar 143: %} f'8 d''8 r2. | %{ bar 144: %} e'2 r2 | | %{ bar 145: %} r4. r2 r8 | | %{ bar 146: %} a'2 r2 | | %{ bar 147: %} c''4 c''4 r2 | | %{ bar 148: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 149: %} R1 | | %{ bar 150: %} c''4 c''4 c''4 r4 | %{ bar 151: %} f'8 d''8 r2. | %{ bar 152: %} e'2 r2 | | %{ bar 153: %} r4. r2 r8 | | %{ bar 154: %} a'2 r2 | | %{ bar 155: %} c''4 c''4 r2 | | %{ bar 156: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 157: %} R1 | | %{ bar 158: %} c''4 c''4 c''4 r4 | %{ bar 159: %} f'8 d''8 r2. | %{ bar 160: %} e'2 r2 | | %{ bar 161: %} r4. r2 r8 | | %{ bar 162: %} a'2 r2 | | %{ bar 163: %} c''4 c''4 r2 | | %{ bar 164: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 165: %} R1 | | %{ bar 166: %} c''4 c''4 c''4 r4 | %{ bar 167: %} f'8 d''8 r2. | %{ bar 168: %} e'2 r2 | | %{ bar 169: %} r4. r2 r8 | | %{ bar 170: %} a'2 r2 | | %{ bar 171: %} c''4 c''4 r2 | | %{ bar 172: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 173: %} R1 | | %{ bar 174: %} c''4 c''4 c''4 r4 | %{ bar 175: %} f'8 d''8 r2. | %{ bar 176: %} e'2 r2 | | %{ bar 177: %} r4. r2 r8 | | %{ bar 178: %} a'2 r2 | | %{ bar 179: %} c''4 c''4 r2 | | %{ bar 180: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 181: %} R1 | | %{ bar 182: %} c''4 c''4 c''4 r4 | %{ bar 183: %} f'8 d''8 r2. | %{ bar 184: %} e'2 r2 | | %{ bar 185: %} r4. r2 r8 | | %{ bar 186: %} a'2 r2 | | %{ bar 187: %} c''4 c''4 r2 | | %{ bar 188: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 189: %} R1 | | %{ bar 190: %} c''4 c''4 c''4 r4 | %{ bar 191: %} f'8 d''8 r2. | %{ bar 192: %} e'2 r2 | | %{ bar 193: %} r4. r2 r8 | | %{ bar 194: %} a'2 r2 | | %{ bar 195: %} c''4 c''4 r2 | | %{ bar 196: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 197: %} R1 | | %{ bar 198: %} c''4 c''4 c''4 r4 | %{ bar 199: %} f'8 d''8 r2. | %{ bar 200: %} e'2 r2 | | %{ bar 201: %} r4. r2 r8 | | %{ bar 202: %} a'2 r2 | | %{ bar 203: %} c''4 c''4 r2 | | %{ bar 204: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 205: %} R1 | | %{ bar 206: %} c''4 c''4 c''4 r4 | %{ bar 207: %} f'8 d''8 r2. | %{ bar 208: %} e'2 r2 | | %{ bar 209: %} r4. r2 r8 | | %{ bar 210: %} a'2 r2 | | %{ bar 211: %} c''4 c''4 r2 | | %{ bar 212: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 213: %} R1 | | %{ bar 214: %} c''4 c''4 c''4 r4 | %{ bar 215: %} f'8 d''8 r2. | %{ bar 216: %} e'2 r2 | | %{ bar 217: %} r4. r2 r8 | | %{ bar 218: %} a'2 r2 | | %{ bar 219: %} c''4 c''4 r2 | | %{ bar 220: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 221: %} R1 | | %{ bar 222: %} c''4 c''4 c''4 r4 | %{ bar 223: %} f'8 d''8 r2. | %{ bar 224: %} e'2 r2 | | %{ bar 225: %} r4. r2 r8 | | %{ bar 226: %} a'2 r2 | | %{ bar 227: %} c''4 c''4 r2 | | %{ bar 228: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 229: %} R1 | | %{ bar 230: %} c''4 c''4 c''4 r4 | %{ bar 231: %} f'8 d''8 r2. | %{ bar 232: %} e'2 r2 | | %{ bar 233: %} r4. r2 r8 | | %{ bar 234: %} a'2 r2 | | %{ bar 235: %} c''4 c''4 r2 | | %{ bar 236: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 237: %} R1 | | %{ bar 238: %} c''4 c''4 c''4 r4 | %{ bar 239: %} f'8 d''8 r2. | %{ bar 240: %} e'2 r2 | | %{ bar 241: %} r4. r2 r8 | | %{ bar 242: %} a'2 r2 | | %{ bar 243: %} c''4 c''4 r2 | | %{ bar 244: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 245: %} R1 | | %{ bar 246: %} c''4 c''4 c''4 r4 | %{ bar 247: %} f'8 d''8 r2. | %{ bar 248: %} e'2 r2 | | %{ bar 249: %} r4. r2 r8 | | %{ bar 250: %} a'2 r2 | | %{ bar 251: %} c''4 c''4 r2 | | %{ bar 252: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 253: %} R1 | | %{ bar 254: %} c''4 c''4 c''4 r4 | %{ bar 255: %} f'8 d''8 r2. | %{ bar 256: %} e'2 r2 | | %{ bar 257: %} r4. r2 r8 | | %{ bar 258: %} a'2 r2 | | %{ bar 259: %} c''4 c''4 r2 | | %{ bar 260: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 261: %} R1 | | %{ bar 262: %} c''4 c''4 c''4 r4 | %{ bar 263: %} f'8 d''8 r2. | %{ bar 264: %} e'2 r2 | | %{ bar 265: %} r4. r2 r8 | | %{ bar 266: %} a'2 r2 | | %{ bar 267: %} c''4 c''4 r2 | | %{ bar 268: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 269: %} R1 | | %{ bar 270: %} c''4 c''4 c''4 r4 | %{ bar 271: %} f'8 d''8 r2. | %{ bar 272: %} e'2 r2 | | %{ bar 273: %} r4. r2 r8 | | %{ bar 274: %} a'2 r2 | | %{ bar 275: %} c''4 c''4 r2 | | %{ bar 276: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 277: %} R1 | | %{ bar 278: %} c''4 c''4 c''4 r4 | %{ bar 279: %} f'8 d''8 r2. | %{ bar 280: %} e'2 r2 | | %{ bar 281: %} r4. r2 r8 | | %{ bar 282: %} a'2 r2 | | %{ bar 283: %} c''4 c''4 r2 | | %{ bar 284: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 285: %} R1 | | %{ bar 286: %} c''4 c''4 c''4 r4 | %{ bar 287: %} f'8 d''8 r2. | %{ bar 288: %} e'2 r2 | | %{ bar 289: %} r4. r2 r8 | | %{ bar 290: %} a'2 r2 | | %{ bar 291: %} c''4 c''4 r2 | | %{ bar 292: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 293: %} R1 | | %{ bar 294: %} c''4 c''4 c''4 r4 | %{ bar 295: %} f'8 d''8 r2. | %{ bar 296: %} e'2 r2 | | %{ bar 297: %} r4. r2 r8 | | %{ bar 298: %} a'2 r2 | | %{ bar 299: %} c''4 c''4 r2 | | %{ bar 300: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 301: %} R1 | | %{ bar 302: %} c''4 c''4 c''4 r4 | %{ bar 303: %} f'8 d''8 r2. | %{ bar 304: %} e'2 r2 | | %{ bar 305: %} r4. r2 r8 | | %{ bar 306: %} a'2 r2 | | %{ bar 307: %} c''4 c''4 r2 | | %{ bar 308: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 309: %} R1 | | %{ bar 310: %} c''4 c''4 c''4 r4 | %{ bar 311: %} f'8 d''8 r2. | %{ bar 312: %} e'2 r2 | | %{ bar 313: %} r4. r2 r8 | | %{ bar 314: %} a'2 r2 | | %{ bar 315: %} c''4 c''4 r2 | | %{ bar 316: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 317: %} R1 | | %{ bar 318: %} c''4 c''4 c''4 r4 | %{ bar 319: %} f'8 d''8 r2. | %{ bar 320: %} e'2 r2 | | %{ bar 321: %} r4. r2 r8 | | %{ bar 322: %} a'2 r2 | | %{ bar 323: %} c''4 c''4 r2 | | %{ bar 324: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 325: %} R1 | | %{ bar 326: %} c''4 c''4 c''4 r4 | %{ bar 327: %} f'8 d''8 r2. | %{ bar 328: %} e'2 r2 | | %{ bar 329: %} r4. r2 r8 | | %{ bar 330: %} a'2 r2 | | %{ bar 331: %} c''4 c''4 r2 | | %{ bar 332: %} d'8 g'4 c'8 b'4 r4 | | %{ bar 333: %} R1 | | %{ bar 334: %} c''4 c''4 c''4 r4 | %{ bar 335: %} f'8 d''8 r2. | %{ bar 336: %} e'2 r2 | | %{ bar 337: %} r4. r2 r8 | } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
