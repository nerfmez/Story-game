# Art direction: how a short request becomes this quality

The first konbini came out well because the request was a full art-direction brief: the format (a collectible
diorama on a square base), the style (cel-shaded 3D that reads as 2D anime, clean surfaces, crisp lines,
soft but colourful neon palette), the focal point and its contrast (warm bright shop against a cold wet night),
two long lists of concrete objects, a list of small motions, and the feeling (quiet, a little lonely, still
warm, slice of life). A short request has none of that. Your job is to write that brief yourself, then build
from it. Never build straight from a one-line request.

## Step 1: write the brief (in the user's language), then build

Fill every heading below. Be concrete: name objects, materials, colours and positions, not adjectives.
Show the user a compact version (6 to 10 lines) together with the top-down plans (see "Plan first" in
SKILL.md), and build only after they pick a plan and say what to cut or add.

1. **Format and layout.** Square diorama base, every part on it, clear layers of space (something low in
   front, the focal subject, something taller behind that closes the view). The layout itself is free and
   new each time: where paths or roads run (or none), where the focal building sits and which way it faces,
   what surrounds it. Edges cut cleanly like a model, a plinth with a name plate.
2. **Subject and focal point.** One building or place that holds the eye and is the main light source. Decide
   what it is lit by and what colour that light is.
3. **Time, weather, season.** Each one changes light, surfaces and motion. Write what each does here (rain:
   wet gloss, puddles, reflections, drips; snow: white caps, soft light, no reflections; dusk: orange sky,
   lights just coming on).
4. **Palette.** Name 4 to 6 colours: the warm focal light, the cool ambient, one or two brand or accent colours
   for signs, the neutral of walls and ground. The contrast between the focal warmth and the surrounding
   coolness is the main design tool; protect it.
5. **Exterior inventory: 15 to 25 objects.** Think as a set dresser walking around the place: entrance,
   signage, furniture by the door, utilities (poles, wires, meters, AC units, drains), traffic (markings,
   signs, signals), vehicles parked without people, plants, notices, the alley, the neighbour. Pick the items
   that make this exact place recognisable.
6. **Interior inventory: 12 to 20 objects** when there is an inside to see through windows: the fixtures of
   that kind of shop or room, lit and full of colourful stock, arranged so the windows show the best of it.
7. **Signs of life without people.** Three to five traces: a forgotten cup, a helmet on a seat, a lit upstairs
   window, an umbrella leaning on a counter, posters about local events.
8. **Motion list: 6 to 10 small loops.** Weather particles, drips, ripples, one mechanical cycle (door,
   signal, fan), one light behaviour (a sign that hums or stutters), steam or smoke, reflections that move.
   Keep all of them subtle; nothing big moves.
9. **Mood sentence.** One line, like "quiet and a little lonely, but warm". Use it to judge every render.

The user's original konbini request is the reference for how much a good brief says; the scene in this repo
is what it produced. A brief that would fit in two lines is too thin.

## Step 2: the house style (keep it unless the user asks otherwise)

- **Cel shading:** three hard light bands, no soft gradients on objects; shadows tinted toward the ambient
  colour (navy at night), never grey.
- **Ink lines:** every solid object has an outline, tinted by its own colour, constant width on screen; thin
  things (wires, rails) read as drawn lines. Flat decals and tiny product have none.
- **Clean surfaces:** flat colours with at most one quiet pattern (pavers, tiles, siding); detail comes from
  more objects, not from texture noise.
- **Light hierarchy:** one dominant warm source (the focal building), two or three secondary sources (street
  lamp, sign, vending machine), the rest dark. Fill lights spill colour without highlights.
- **Wet or reflective ground** is where the night look comes from: hard highlights under real lamps and
  vertical reflection streaks broken into dashes, peaking at each light's mirror point.
- **Glow** only on things that are actually lights; keep everything else below the bloom threshold.
- **Colour:** soft but saturated. No pure black or white; darkest tones navy or violet, whites slightly warm
  indoors and slightly cool outdoors.
- **Scale and density:** real-world metres, about an 18 m square. Dense around the focal point, sparse at the
  edges so the eye returns to the centre.

## Step 3: judge the render against the brief

For each render ask: does the focal point win, is the warm/cool contrast clear, do the signature items read at
overview distance, is anything floating, clipped or overlapping, is text readable, does it match the mood
sentence. Fix the biggest problem first, render again. The first render is never the final one.

## Short requests and how to expand them

- "ร้านราเมนตอนหิมะตก": focal = ramen shop with steamy window and noren curtain, red lantern; snow on roofs,
  rails and bikes; palette warm orange interior, blue-white snow, red lantern; exterior: noren, menu board,
  bicycles, vending machine, utility pole, snow shovel, footprints in snow; interior: counter seats, big pots
  with steam, ticket machine, bowls; motion: snowfall, steam, lantern sway, noren sway, a drip of meltwater.
- "สถานีรถไฟเล็กๆ ตอนเย็น": focal = small platform with a lit waiting room; dusk sky; palette orange sky, teal
  shadows, warm windows; exterior: platform edge line, signal, level crossing with barrier, bench, timetable,
  bicycle racks, vending machine, cables; motion: crossing lights and barrier cycle, a train passing on a loop,
  birds, a flickering platform lamp.
- "ร้านหนังสือเก่ามุมถนนฝนตก": focal = shop window stacked with books and a desk lamp; rain; palette amber,
  deep green, wet navy; signature items: outdoor book cart under an awning, a worn shop stool, hand-written
  price cards, a ladder inside; motion: rain, drips from the awning, a page fluttering in the doorway fan.
