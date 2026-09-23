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
2/4
5 6' | 3 - | 0 0 |
5 0 | 0 0 |
5 5 | 5 3 | 2 0 | 0 0 |
1 2 | 1 0 | 0 0 |
5 6' | q3 q2 q1 q0 | 0 0 |
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
| |
1 2 | 1 0
7 0
4 0
1' 0
2' 0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
1 2 | 1 0
7. q0
1'. q0
2'. q0
5 - | 0 0 |
5 6' | 0 0 |
3. q0 | 2 q1 q0 | 0 0 |
q3 q2 q1 q0
5 5 | 5 5 | 0 0 |
1 2 | 1 0 | 0 0 |
|
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
     \time 2/4  \note-mod "5" g'4  \note-mod "6" a''4^. | \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 2: %}
 \note-mod "3" e'4
 ~  \note-mod "–" e'4 | | %{ bar 3: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 4: %}
 \note-mod "5" g'4
 \note-mod "0" r4 | | %{ bar 5: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 6: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 7: %}
 \note-mod "5" g'4
 \note-mod "3" e'4 | | %{ bar 8: %}
 \note-mod "2" d'4
 \note-mod "0" r4 | | %{ bar 9: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 10: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 11: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 13: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 15: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 16: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 17: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 18: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 19: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 20: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 21: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | | %{ bar 22: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 23: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 24: %}
 \note-mod "7" b'4
 \note-mod "0" r4 | %{ bar 25: %}
 \note-mod "4" f'4
 \note-mod "0" r4 | %{ bar 26: %}
 \note-mod "1" c''4^.
 \note-mod "0" r4 | %{ bar 27: %}
 \note-mod "2" d''4^.
 \note-mod "0" r4 \once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 28: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 29: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 30: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 31: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 32: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 33: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 34: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 35: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 36: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 37: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 38: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 39: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 40: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 41: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 42: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 43: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 44: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 45: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 46: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 47: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 48: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 49: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 50: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 51: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 52: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 53: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 54: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 55: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 56: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 57: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 58: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 59: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 60: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 61: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 62: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 63: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 64: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 65: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 66: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 67: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 68: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 69: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 70: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 71: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 72: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 73: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 74: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 75: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 76: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 77: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 78: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 79: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 80: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 81: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 82: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 83: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 84: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 85: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 86: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 87: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 88: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 89: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 90: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 91: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 92: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 93: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 94: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 95: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 96: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 97: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 98: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 99: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 100: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 101: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 102: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 103: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 104: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 105: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 106: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 107: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 108: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 109: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 110: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 111: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 112: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 113: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 114: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 115: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 116: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 117: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 118: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 119: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 120: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 121: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 122: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 123: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 124: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 125: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 126: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 127: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 128: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 129: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 130: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 131: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 132: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 133: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 134: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 135: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 136: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 137: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 138: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 139: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 140: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 141: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 142: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 143: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 144: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 145: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 146: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 147: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 148: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 149: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 150: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 151: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 152: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 153: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 154: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 155: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 156: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 157: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 158: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 159: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 160: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 161: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 162: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 163: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 164: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 165: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 166: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 167: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 168: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 169: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 170: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 171: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 172: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 173: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 174: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 175: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 176: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 177: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 178: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 179: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 180: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 181: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 182: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 183: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 184: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 185: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 186: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 187: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 188: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 189: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 190: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 191: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 192: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 193: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 194: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 195: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 196: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 197: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 198: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 199: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 200: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 201: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 202: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 203: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 204: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 205: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 206: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 207: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 208: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 209: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 210: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 211: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 212: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 213: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 214: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 215: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 216: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 217: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 218: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 219: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 220: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 221: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 222: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 223: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 224: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 225: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 226: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 227: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 228: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 229: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 230: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 231: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 232: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 233: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 234: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 235: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 236: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 237: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 238: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 239: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 240: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 241: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 242: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 243: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 244: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 245: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 246: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 247: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 248: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 249: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 250: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 251: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 252: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 253: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 254: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 255: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 256: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 257: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 258: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 259: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 260: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 261: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 262: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 263: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 264: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 265: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 266: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 267: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 268: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 269: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 270: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 271: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 272: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 273: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 274: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 275: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 276: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 277: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 278: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 279: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 280: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 281: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 282: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 283: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 284: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 285: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 286: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 287: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 288: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 289: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 290: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 291: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 292: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 293: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 294: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 295: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 296: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 297: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 298: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 299: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 300: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 301: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 302: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 303: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 304: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 305: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 306: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 307: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 308: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 309: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 310: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 311: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 312: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 313: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 314: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 315: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 316: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 317: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 318: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 319: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 320: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 321: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 322: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 323: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 324: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 325: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 326: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 327: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 328: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 329: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 330: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 331: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 332: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 333: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 334: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 335: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 336: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 337: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 338: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 339: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 340: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 341: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 342: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 343: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 344: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 345: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 346: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 347: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 348: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 349: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 350: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 351: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 352: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 353: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 354: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 355: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 356: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 357: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 358: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 359: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 360: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 361: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 362: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 363: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 364: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 365: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 366: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 367: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 368: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 369: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 370: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 371: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 372: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 373: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 374: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 375: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 376: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 377: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 378: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 379: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 380: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 381: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 382: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 383: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 384: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 385: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 386: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 387: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 388: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 389: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 390: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 391: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 392: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 393: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 394: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 395: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 396: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 397: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 398: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 399: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 400: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 401: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 402: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 403: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 404: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 405: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 406: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 407: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 408: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 409: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 410: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 411: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 412: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 413: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 414: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 415: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 416: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 417: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 418: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 419: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 420: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 421: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 422: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 423: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 424: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 425: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 426: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 427: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 428: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 429: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 430: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 431: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 432: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 433: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 434: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 435: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 436: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 437: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 438: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 439: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 440: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 441: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 442: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 443: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 444: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 445: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 446: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 447: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 448: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 449: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 450: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 451: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 452: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 453: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 454: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 455: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 456: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 457: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 458: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 459: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | | %{ bar 460: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 461: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | %{ bar 462: %}
 \note-mod "7" b'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 463: %}
 \note-mod "1" c''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| %{ bar 464: %}
 \note-mod "2" d''4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
\once \override Tie.transparent = ##t \once \override Tie.staff-position = #0 | %{ bar 465: %}
 \note-mod "5" g'4
 ~  \note-mod "–" g'4 | | %{ bar 466: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 467: %}
 \note-mod "5" g'4
 \note-mod "6" a''4^. | | %{ bar 468: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 469: %}
 \note-mod "3" e'4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[]
| | %{ bar 470: %}
 \note-mod "2" d'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| | %{ bar 471: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 472: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "0" r8]
| %{ bar 473: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 474: %}
 \note-mod "5" g'4
 \note-mod "5" g'4 | | %{ bar 475: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | %{ bar 476: %}
 \note-mod "1" c'4
 \note-mod "2" d'4 | | %{ bar 477: %}
 \note-mod "1" c'4
 \note-mod "0" r4 | | %{ bar 478: %}
 \note-mod "0" r4
 \note-mod "0" r4 | | \bar "|." } }
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
    \new Staff { \new Voice="X" { \time 2/4 g'4 a''4 | | %{ bar 2: %} e'2 | | %{ bar 3: %} R2 | | %{ bar 4: %} g'4 r4 | | %{ bar 5: %} R2 | | %{ bar 6: %} g'4 g'4 | | %{ bar 7: %} g'4 e'4 | | %{ bar 8: %} d'4 r4 | | %{ bar 9: %} R2 | | %{ bar 10: %} c'4 d'4 | | %{ bar 11: %} c'4 r4 | | %{ bar 12: %} R2 | | %{ bar 13: %} g'4 a''4 | | %{ bar 14: %} e'8 d'8 c'8 r8 | | %{ bar 15: %} R2 | | %{ bar 16: %} g'4 g'4 | | %{ bar 17: %} g'4 g'4 | | %{ bar 18: %} R2 | | %{ bar 19: %} c'4 d'4 | | %{ bar 20: %} c'4 r4 | | %{ bar 21: %} R2 | | | | %{ bar 22: %} c'4 d'4 | | %{ bar 23: %} c'4 r4 | %{ bar 24: %} b'4 r4 | %{ bar 25: %} f'4 r4 | %{ bar 26: %} c''4 r4 | %{ bar 27: %} d''4 r4 | %{ bar 28: %} g'2 | | %{ bar 29: %} R2 | | %{ bar 30: %} g'4 a''4 | | %{ bar 31: %} R2 | | %{ bar 32: %} e'4. r8 | | %{ bar 33: %} d'4 c'8 r8 | | %{ bar 34: %} R2 | | %{ bar 35: %} e'8 d'8 c'8 r8 | %{ bar 36: %} g'4 g'4 | | %{ bar 37: %} g'4 g'4 | | %{ bar 38: %} R2 | | %{ bar 39: %} c'4 d'4 | | %{ bar 40: %} c'4 r4 | | %{ bar 41: %} R2 | | | %{ bar 42: %} c'4 d'4 | | %{ bar 43: %} c'4 r4 | %{ bar 44: %} b'4. r8 | %{ bar 45: %} c''4. r8 | %{ bar 46: %} d''4. r8 | %{ bar 47: %} g'2 | | %{ bar 48: %} R2 | | %{ bar 49: %} g'4 a''4 | | %{ bar 50: %} R2 | | %{ bar 51: %} e'4. r8 | | %{ bar 52: %} d'4 c'8 r8 | | %{ bar 53: %} R2 | | %{ bar 54: %} e'8 d'8 c'8 r8 | %{ bar 55: %} g'4 g'4 | | %{ bar 56: %} g'4 g'4 | | %{ bar 57: %} R2 | | %{ bar 58: %} c'4 d'4 | | %{ bar 59: %} c'4 r4 | | %{ bar 60: %} R2 | | | %{ bar 61: %} c'4 d'4 | | %{ bar 62: %} c'4 r4 | %{ bar 63: %} b'4. r8 | %{ bar 64: %} c''4. r8 | %{ bar 65: %} d''4. r8 | %{ bar 66: %} g'2 | | %{ bar 67: %} R2 | | %{ bar 68: %} g'4 a''4 | | %{ bar 69: %} R2 | | %{ bar 70: %} e'4. r8 | | %{ bar 71: %} d'4 c'8 r8 | | %{ bar 72: %} R2 | | %{ bar 73: %} e'8 d'8 c'8 r8 | %{ bar 74: %} g'4 g'4 | | %{ bar 75: %} g'4 g'4 | | %{ bar 76: %} R2 | | %{ bar 77: %} c'4 d'4 | | %{ bar 78: %} c'4 r4 | | %{ bar 79: %} R2 | | | %{ bar 80: %} c'4 d'4 | | %{ bar 81: %} c'4 r4 | %{ bar 82: %} b'4. r8 | %{ bar 83: %} c''4. r8 | %{ bar 84: %} d''4. r8 | %{ bar 85: %} g'2 | | %{ bar 86: %} R2 | | %{ bar 87: %} g'4 a''4 | | %{ bar 88: %} R2 | | %{ bar 89: %} e'4. r8 | | %{ bar 90: %} d'4 c'8 r8 | | %{ bar 91: %} R2 | | %{ bar 92: %} e'8 d'8 c'8 r8 | %{ bar 93: %} g'4 g'4 | | %{ bar 94: %} g'4 g'4 | | %{ bar 95: %} R2 | | %{ bar 96: %} c'4 d'4 | | %{ bar 97: %} c'4 r4 | | %{ bar 98: %} R2 | | | %{ bar 99: %} c'4 d'4 | | %{ bar 100: %} c'4 r4 | %{ bar 101: %} b'4. r8 | %{ bar 102: %} c''4. r8 | %{ bar 103: %} d''4. r8 | %{ bar 104: %} g'2 | | %{ bar 105: %} R2 | | %{ bar 106: %} g'4 a''4 | | %{ bar 107: %} R2 | | %{ bar 108: %} e'4. r8 | | %{ bar 109: %} d'4 c'8 r8 | | %{ bar 110: %} R2 | | %{ bar 111: %} e'8 d'8 c'8 r8 | %{ bar 112: %} g'4 g'4 | | %{ bar 113: %} g'4 g'4 | | %{ bar 114: %} R2 | | %{ bar 115: %} c'4 d'4 | | %{ bar 116: %} c'4 r4 | | %{ bar 117: %} R2 | | | %{ bar 118: %} c'4 d'4 | | %{ bar 119: %} c'4 r4 | %{ bar 120: %} b'4. r8 | %{ bar 121: %} c''4. r8 | %{ bar 122: %} d''4. r8 | %{ bar 123: %} g'2 | | %{ bar 124: %} R2 | | %{ bar 125: %} g'4 a''4 | | %{ bar 126: %} R2 | | %{ bar 127: %} e'4. r8 | | %{ bar 128: %} d'4 c'8 r8 | | %{ bar 129: %} R2 | | %{ bar 130: %} e'8 d'8 c'8 r8 | %{ bar 131: %} g'4 g'4 | | %{ bar 132: %} g'4 g'4 | | %{ bar 133: %} R2 | | %{ bar 134: %} c'4 d'4 | | %{ bar 135: %} c'4 r4 | | %{ bar 136: %} R2 | | | %{ bar 137: %} c'4 d'4 | | %{ bar 138: %} c'4 r4 | %{ bar 139: %} b'4. r8 | %{ bar 140: %} c''4. r8 | %{ bar 141: %} d''4. r8 | %{ bar 142: %} g'2 | | %{ bar 143: %} R2 | | %{ bar 144: %} g'4 a''4 | | %{ bar 145: %} R2 | | %{ bar 146: %} e'4. r8 | | %{ bar 147: %} d'4 c'8 r8 | | %{ bar 148: %} R2 | | %{ bar 149: %} e'8 d'8 c'8 r8 | %{ bar 150: %} g'4 g'4 | | %{ bar 151: %} g'4 g'4 | | %{ bar 152: %} R2 | | %{ bar 153: %} c'4 d'4 | | %{ bar 154: %} c'4 r4 | | %{ bar 155: %} R2 | | | %{ bar 156: %} c'4 d'4 | | %{ bar 157: %} c'4 r4 | %{ bar 158: %} b'4. r8 | %{ bar 159: %} c''4. r8 | %{ bar 160: %} d''4. r8 | %{ bar 161: %} g'2 | | %{ bar 162: %} R2 | | %{ bar 163: %} g'4 a''4 | | %{ bar 164: %} R2 | | %{ bar 165: %} e'4. r8 | | %{ bar 166: %} d'4 c'8 r8 | | %{ bar 167: %} R2 | | %{ bar 168: %} e'8 d'8 c'8 r8 | %{ bar 169: %} g'4 g'4 | | %{ bar 170: %} g'4 g'4 | | %{ bar 171: %} R2 | | %{ bar 172: %} c'4 d'4 | | %{ bar 173: %} c'4 r4 | | %{ bar 174: %} R2 | | | %{ bar 175: %} c'4 d'4 | | %{ bar 176: %} c'4 r4 | %{ bar 177: %} b'4. r8 | %{ bar 178: %} c''4. r8 | %{ bar 179: %} d''4. r8 | %{ bar 180: %} g'2 | | %{ bar 181: %} R2 | | %{ bar 182: %} g'4 a''4 | | %{ bar 183: %} R2 | | %{ bar 184: %} e'4. r8 | | %{ bar 185: %} d'4 c'8 r8 | | %{ bar 186: %} R2 | | %{ bar 187: %} e'8 d'8 c'8 r8 | %{ bar 188: %} g'4 g'4 | | %{ bar 189: %} g'4 g'4 | | %{ bar 190: %} R2 | | %{ bar 191: %} c'4 d'4 | | %{ bar 192: %} c'4 r4 | | %{ bar 193: %} R2 | | | %{ bar 194: %} c'4 d'4 | | %{ bar 195: %} c'4 r4 | %{ bar 196: %} b'4. r8 | %{ bar 197: %} c''4. r8 | %{ bar 198: %} d''4. r8 | %{ bar 199: %} g'2 | | %{ bar 200: %} R2 | | %{ bar 201: %} g'4 a''4 | | %{ bar 202: %} R2 | | %{ bar 203: %} e'4. r8 | | %{ bar 204: %} d'4 c'8 r8 | | %{ bar 205: %} R2 | | %{ bar 206: %} e'8 d'8 c'8 r8 | %{ bar 207: %} g'4 g'4 | | %{ bar 208: %} g'4 g'4 | | %{ bar 209: %} R2 | | %{ bar 210: %} c'4 d'4 | | %{ bar 211: %} c'4 r4 | | %{ bar 212: %} R2 | | | %{ bar 213: %} c'4 d'4 | | %{ bar 214: %} c'4 r4 | %{ bar 215: %} b'4. r8 | %{ bar 216: %} c''4. r8 | %{ bar 217: %} d''4. r8 | %{ bar 218: %} g'2 | | %{ bar 219: %} R2 | | %{ bar 220: %} g'4 a''4 | | %{ bar 221: %} R2 | | %{ bar 222: %} e'4. r8 | | %{ bar 223: %} d'4 c'8 r8 | | %{ bar 224: %} R2 | | %{ bar 225: %} e'8 d'8 c'8 r8 | %{ bar 226: %} g'4 g'4 | | %{ bar 227: %} g'4 g'4 | | %{ bar 228: %} R2 | | %{ bar 229: %} c'4 d'4 | | %{ bar 230: %} c'4 r4 | | %{ bar 231: %} R2 | | | %{ bar 232: %} c'4 d'4 | | %{ bar 233: %} c'4 r4 | %{ bar 234: %} b'4. r8 | %{ bar 235: %} c''4. r8 | %{ bar 236: %} d''4. r8 | %{ bar 237: %} g'2 | | %{ bar 238: %} R2 | | %{ bar 239: %} g'4 a''4 | | %{ bar 240: %} R2 | | %{ bar 241: %} e'4. r8 | | %{ bar 242: %} d'4 c'8 r8 | | %{ bar 243: %} R2 | | %{ bar 244: %} e'8 d'8 c'8 r8 | %{ bar 245: %} g'4 g'4 | | %{ bar 246: %} g'4 g'4 | | %{ bar 247: %} R2 | | %{ bar 248: %} c'4 d'4 | | %{ bar 249: %} c'4 r4 | | %{ bar 250: %} R2 | | | %{ bar 251: %} c'4 d'4 | | %{ bar 252: %} c'4 r4 | %{ bar 253: %} b'4. r8 | %{ bar 254: %} c''4. r8 | %{ bar 255: %} d''4. r8 | %{ bar 256: %} g'2 | | %{ bar 257: %} R2 | | %{ bar 258: %} g'4 a''4 | | %{ bar 259: %} R2 | | %{ bar 260: %} e'4. r8 | | %{ bar 261: %} d'4 c'8 r8 | | %{ bar 262: %} R2 | | %{ bar 263: %} e'8 d'8 c'8 r8 | %{ bar 264: %} g'4 g'4 | | %{ bar 265: %} g'4 g'4 | | %{ bar 266: %} R2 | | %{ bar 267: %} c'4 d'4 | | %{ bar 268: %} c'4 r4 | | %{ bar 269: %} R2 | | | %{ bar 270: %} c'4 d'4 | | %{ bar 271: %} c'4 r4 | %{ bar 272: %} b'4. r8 | %{ bar 273: %} c''4. r8 | %{ bar 274: %} d''4. r8 | %{ bar 275: %} g'2 | | %{ bar 276: %} R2 | | %{ bar 277: %} g'4 a''4 | | %{ bar 278: %} R2 | | %{ bar 279: %} e'4. r8 | | %{ bar 280: %} d'4 c'8 r8 | | %{ bar 281: %} R2 | | %{ bar 282: %} e'8 d'8 c'8 r8 | %{ bar 283: %} g'4 g'4 | | %{ bar 284: %} g'4 g'4 | | %{ bar 285: %} R2 | | %{ bar 286: %} c'4 d'4 | | %{ bar 287: %} c'4 r4 | | %{ bar 288: %} R2 | | | %{ bar 289: %} c'4 d'4 | | %{ bar 290: %} c'4 r4 | %{ bar 291: %} b'4. r8 | %{ bar 292: %} c''4. r8 | %{ bar 293: %} d''4. r8 | %{ bar 294: %} g'2 | | %{ bar 295: %} R2 | | %{ bar 296: %} g'4 a''4 | | %{ bar 297: %} R2 | | %{ bar 298: %} e'4. r8 | | %{ bar 299: %} d'4 c'8 r8 | | %{ bar 300: %} R2 | | %{ bar 301: %} e'8 d'8 c'8 r8 | %{ bar 302: %} g'4 g'4 | | %{ bar 303: %} g'4 g'4 | | %{ bar 304: %} R2 | | %{ bar 305: %} c'4 d'4 | | %{ bar 306: %} c'4 r4 | | %{ bar 307: %} R2 | | | %{ bar 308: %} c'4 d'4 | | %{ bar 309: %} c'4 r4 | %{ bar 310: %} b'4. r8 | %{ bar 311: %} c''4. r8 | %{ bar 312: %} d''4. r8 | %{ bar 313: %} g'2 | | %{ bar 314: %} R2 | | %{ bar 315: %} g'4 a''4 | | %{ bar 316: %} R2 | | %{ bar 317: %} e'4. r8 | | %{ bar 318: %} d'4 c'8 r8 | | %{ bar 319: %} R2 | | %{ bar 320: %} e'8 d'8 c'8 r8 | %{ bar 321: %} g'4 g'4 | | %{ bar 322: %} g'4 g'4 | | %{ bar 323: %} R2 | | %{ bar 324: %} c'4 d'4 | | %{ bar 325: %} c'4 r4 | | %{ bar 326: %} R2 | | | %{ bar 327: %} c'4 d'4 | | %{ bar 328: %} c'4 r4 | %{ bar 329: %} b'4. r8 | %{ bar 330: %} c''4. r8 | %{ bar 331: %} d''4. r8 | %{ bar 332: %} g'2 | | %{ bar 333: %} R2 | | %{ bar 334: %} g'4 a''4 | | %{ bar 335: %} R2 | | %{ bar 336: %} e'4. r8 | | %{ bar 337: %} d'4 c'8 r8 | | %{ bar 338: %} R2 | | %{ bar 339: %} e'8 d'8 c'8 r8 | %{ bar 340: %} g'4 g'4 | | %{ bar 341: %} g'4 g'4 | | %{ bar 342: %} R2 | | %{ bar 343: %} c'4 d'4 | | %{ bar 344: %} c'4 r4 | | %{ bar 345: %} R2 | | | %{ bar 346: %} c'4 d'4 | | %{ bar 347: %} c'4 r4 | %{ bar 348: %} b'4. r8 | %{ bar 349: %} c''4. r8 | %{ bar 350: %} d''4. r8 | %{ bar 351: %} g'2 | | %{ bar 352: %} R2 | | %{ bar 353: %} g'4 a''4 | | %{ bar 354: %} R2 | | %{ bar 355: %} e'4. r8 | | %{ bar 356: %} d'4 c'8 r8 | | %{ bar 357: %} R2 | | %{ bar 358: %} e'8 d'8 c'8 r8 | %{ bar 359: %} g'4 g'4 | | %{ bar 360: %} g'4 g'4 | | %{ bar 361: %} R2 | | %{ bar 362: %} c'4 d'4 | | %{ bar 363: %} c'4 r4 | | %{ bar 364: %} R2 | | | %{ bar 365: %} c'4 d'4 | | %{ bar 366: %} c'4 r4 | %{ bar 367: %} b'4. r8 | %{ bar 368: %} c''4. r8 | %{ bar 369: %} d''4. r8 | %{ bar 370: %} g'2 | | %{ bar 371: %} R2 | | %{ bar 372: %} g'4 a''4 | | %{ bar 373: %} R2 | | %{ bar 374: %} e'4. r8 | | %{ bar 375: %} d'4 c'8 r8 | | %{ bar 376: %} R2 | | %{ bar 377: %} e'8 d'8 c'8 r8 | %{ bar 378: %} g'4 g'4 | | %{ bar 379: %} g'4 g'4 | | %{ bar 380: %} R2 | | %{ bar 381: %} c'4 d'4 | | %{ bar 382: %} c'4 r4 | | %{ bar 383: %} R2 | | | %{ bar 384: %} c'4 d'4 | | %{ bar 385: %} c'4 r4 | %{ bar 386: %} b'4. r8 | %{ bar 387: %} c''4. r8 | %{ bar 388: %} d''4. r8 | %{ bar 389: %} g'2 | | %{ bar 390: %} R2 | | %{ bar 391: %} g'4 a''4 | | %{ bar 392: %} R2 | | %{ bar 393: %} e'4. r8 | | %{ bar 394: %} d'4 c'8 r8 | | %{ bar 395: %} R2 | | %{ bar 396: %} e'8 d'8 c'8 r8 | %{ bar 397: %} g'4 g'4 | | %{ bar 398: %} g'4 g'4 | | %{ bar 399: %} R2 | | %{ bar 400: %} c'4 d'4 | | %{ bar 401: %} c'4 r4 | | %{ bar 402: %} R2 | | | %{ bar 403: %} c'4 d'4 | | %{ bar 404: %} c'4 r4 | %{ bar 405: %} b'4. r8 | %{ bar 406: %} c''4. r8 | %{ bar 407: %} d''4. r8 | %{ bar 408: %} g'2 | | %{ bar 409: %} R2 | | %{ bar 410: %} g'4 a''4 | | %{ bar 411: %} R2 | | %{ bar 412: %} e'4. r8 | | %{ bar 413: %} d'4 c'8 r8 | | %{ bar 414: %} R2 | | %{ bar 415: %} e'8 d'8 c'8 r8 | %{ bar 416: %} g'4 g'4 | | %{ bar 417: %} g'4 g'4 | | %{ bar 418: %} R2 | | %{ bar 419: %} c'4 d'4 | | %{ bar 420: %} c'4 r4 | | %{ bar 421: %} R2 | | | %{ bar 422: %} c'4 d'4 | | %{ bar 423: %} c'4 r4 | %{ bar 424: %} b'4. r8 | %{ bar 425: %} c''4. r8 | %{ bar 426: %} d''4. r8 | %{ bar 427: %} g'2 | | %{ bar 428: %} R2 | | %{ bar 429: %} g'4 a''4 | | %{ bar 430: %} R2 | | %{ bar 431: %} e'4. r8 | | %{ bar 432: %} d'4 c'8 r8 | | %{ bar 433: %} R2 | | %{ bar 434: %} e'8 d'8 c'8 r8 | %{ bar 435: %} g'4 g'4 | | %{ bar 436: %} g'4 g'4 | | %{ bar 437: %} R2 | | %{ bar 438: %} c'4 d'4 | | %{ bar 439: %} c'4 r4 | | %{ bar 440: %} R2 | | | %{ bar 441: %} c'4 d'4 | | %{ bar 442: %} c'4 r4 | %{ bar 443: %} b'4. r8 | %{ bar 444: %} c''4. r8 | %{ bar 445: %} d''4. r8 | %{ bar 446: %} g'2 | | %{ bar 447: %} R2 | | %{ bar 448: %} g'4 a''4 | | %{ bar 449: %} R2 | | %{ bar 450: %} e'4. r8 | | %{ bar 451: %} d'4 c'8 r8 | | %{ bar 452: %} R2 | | %{ bar 453: %} e'8 d'8 c'8 r8 | %{ bar 454: %} g'4 g'4 | | %{ bar 455: %} g'4 g'4 | | %{ bar 456: %} R2 | | %{ bar 457: %} c'4 d'4 | | %{ bar 458: %} c'4 r4 | | %{ bar 459: %} R2 | | | %{ bar 460: %} c'4 d'4 | | %{ bar 461: %} c'4 r4 | %{ bar 462: %} b'4. r8 | %{ bar 463: %} c''4. r8 | %{ bar 464: %} d''4. r8 | %{ bar 465: %} g'2 | | %{ bar 466: %} R2 | | %{ bar 467: %} g'4 a''4 | | %{ bar 468: %} R2 | | %{ bar 469: %} e'4. r8 | | %{ bar 470: %} d'4 c'8 r8 | | %{ bar 471: %} R2 | | %{ bar 472: %} e'8 d'8 c'8 r8 | %{ bar 473: %} g'4 g'4 | | %{ bar 474: %} g'4 g'4 | | %{ bar 475: %} R2 | | %{ bar 476: %} c'4 d'4 | | %{ bar 477: %} c'4 r4 | | %{ bar 478: %} r2 | | } }
% === END MIDI STAFF ===

>>
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
