
Files Stored Directly in Game source folder
| Extension | Files |
|-----------|------:|
| .p3d      | 1965  |
| .png      | 930   |
| .mfk      | 344   |
| .con      | 255   |
| .pag      | 119   |
| .scr      | 68    |
| .rmv      | 17    |
| .prj | 13 |
| .err | 11 |
| .rcf | 10 |
| .dll | 10 |
| .cho | 8 |
| .exe | 1 |
| .txt | 2 |
| .rsd | 2 |
| .pem | 1 |
| .typ | 1 |
| .ini | 1 |
| .x | 1 |
| .s | 1 |
| .f | 1 |
| .g | 1 |
| .e | 1 |
| .config | 1 |
| .i | 1 |

Files stored within .rcf archives
| Extension | Files |
|-----------|------:|
| .rsd      | 5567  |
| .spt      | 125   |
| .rms      | 8     |

### **Core Engine Assets (Pure3D)**
* **`.p3d` (Pure3D):** The backbone of the game's visuals. These proprietary files contain 3D models (characters, vehicles, map chunks), skeletons, animations, and textures. 
* **`.rcf` (Radical Cement File):** The main archive container format, The game uses these to store and organize assets in a way that allows for efficient streaming and loading. Inside these archives, you'll find various file types, including `.rsd` audio files, `.spt` sound scripts, and `.rms` music composition files.
* **`.rmv` (Radical Movie):** Video files used for the game's FMV (Full Motion Video) cutscenes. These are actually standard Bink Video (`.bik`) files that the developers simply renamed.
* **`.rsd` (Radical Sound Data):** The proprietary audio format used for the game's music tracks, sound effects, and voice lines.
* **`.cho` (Choreography):** Data files used specifically to sync character facial animations and lip-movements with the `.rsd` voice audio during in-game dialogue.

### **Scripting & Gameplay Configuration**
* **`.mfk` (Mission Files):** Plain-text scripting files used to dictate game logic. They control mission parameters, dialogue triggers, stage sequences, objective markers, and timers. 
* **`.con` (Configuration):** Plain-text settings files used primarily to tune gameplay numbers. Modders frequently edit these to change vehicle handling physics, top speeds, weight, and character stats.

### **UI & Menus (Scrooby Engine)**
* **`.prj` (Project):** Master project files used by Radical's Scrooby UI engine to define how the interface ties together.
* **`.scr` (Screen):** Scrooby UI files that define a specific "Screen" state (e.g., the Main Menu or the Pause Menu) by grouping together multiple visual elements.
* **`.pag` (Page):** Scrooby UI files that act as individual layers or "Pages" of 2D visual elements, fonts, and bounding boxes that sit inside a `.scr` file.
* **`.typ` (Type):** Binary type definition files used by Radical UI/object systems. The current sample appears to store interface/class metadata as a little-endian stream of records, with no separate file header observed in the captured file. A parser can be built with the following structure:
	* **Integer encoding:** all integers are 32-bit little-endian unsigned values.
	* **Record markers:** the stream is organized around 32-bit markers.
		* `0x43` indicates an interface wrapper/start record.
		* `0x40` indicates a name-bearing type/interface record.
		* `0x41` indicates a method record.
		* `0x0C` appears in parameter entries and should be treated as an alternate parameter marker.
	* **Type/interface record layout:**
		* `u32 marker` (`0x43` or `0x40`).
		* If the marker is `0x43`, read and skip one additional `u32` wrapper/flags value, then expect the next record to be `0x40`.
		* Read the type name as a length-prefixed string: `u32 byte_length` followed by `byte_length` raw bytes.
		* The string payload is not plain C text. In the sample, the useful text ends at the first `0x00` byte and is followed by `0xFD` padding bytes up to the next 4-byte boundary. A parser should strip both the null terminator and any trailing `0xFD` padding before exposing the string.
		* Read `u32 declared_method_count` and `u32 inherited_method_count`.
	* **Method record layout:**
		* Each method begins with `u32 marker` (`0x41`).
		* Read the method name as the same length-prefixed padded string format described above.
		* Read `u32 parameter_count`.
		* Read and ignore two additional `u32` metadata values. Their meaning is not yet confirmed, but they are present in the sample and must be skipped to stay in sync.
		* Read the return type string using the same string format.
		* For each parameter, read a `u32 marker` and then the parameter name string if the marker is `0x41` or `0x0C`.
	* **Traversal strategy:** use `max(declared_method_count, inherited_method_count)` as the number of method slots to inspect, but stop early on EOF or when an unexpected marker is encountered. This makes the parser tolerant of partially understood files.
	* **Practical parsing rule:** decode strings as binary blobs rather than text, trim at the first `0x00` or `0xFD` byte, and keep the parser defensive because some records are likely derived from RTTI-like metadata rather than a strictly documented schema.
	* **Observed sample output:** the parsed structure currently resolves to a list of interfaces with `Name`, `DeclaredMethodCount`, `InheritedMethodCount`, and `Methods[]`, where each method contains `Name`, `ReturnType`, and `Parameters[]`.

### **Localization & Language Strings**
* **`.e`, `.f`, `.g`, `.i`, `.s`, `.x`:** These single-letter extensions act as language identifiers for localization. They are typically appended to text scripts or audio files so the engine knows which regional variant to load (`.e` for English, `.f` for French, `.g` for German, `.i` for Italian, `.s` for Spanish).

### **Standard System & Logs**
* **`.png`, `.txt`, `.ini`, `.config`:** Standard image, text, initialization, and .NET configuration files. In your specific directory, these are likely leftovers from modern modding tools or launcher setups rather than original 2003 game assets.
* **`.err`:** Error log files generated by the game engine when it crashes or fails to load an asset.
* **`.pem`:** Security certificate files. The base game doesn't use these; they are almost certainly used by the Donut Team launcher for secure connections or modern multiplayer features.



### **Audio & Sound Scripting (.rcf Archive Contents)**
* **`.rsd` (Radical Sound Data):** The primary audio format used by the game for sound effects, dialogue, and music. To edit these for custom mods, community tools are used to convert standard audio into 24000Hz Mono `.wav` files for sound effects, or 24000Hz Stereo `.wav` files for music, before packing them back into the `.rsd` format.
* **`.spt` (Sound/Dialogue Scripts):** Script files that manage audio and dialogue events. A primary example is `dialog.spt`, which tells the game engine where to find specific dialogue `.rsd` files, how many pieces of dialogue exist, and the gameplay context in which they should be triggered.


### **.rms (Radical Music Script) Detailed Structure**
The `.rms` format is a compiled binary composition file generated for the "radmusic" subsystem of the Radical sound engine. Based on hex analysis of `ambience.rms`, the file acts as a serialized object database that controls dynamic audio, mixing, and regional transitions.

It is entirely composed of 32-bit (4-byte) little-endian integers representing sizes, object counts, and memory offsets, interspersed with null-terminated ASCII strings. The file structure can be broken down into four primary semantic blocks:

#### **1. Schema & Property Dictionary**
The file begins with the signature string `radmusic_comp`. Following this is a dictionary of variable names and data types used by the C++ engine to deserialize the objects. 
* **Memory Parameters:** Variables like `sound_memory_max`, `cache_memory_max`, and `stream_size_min`.
* **Audio Data Structures:** Definitions for internal objects like `audio_format`, `channels`, `bit_resolution`, and `sampling_rate`.
* **Logic Components:** Names of engine classes such as `fade_transition`, `event_matrix`, `clip`, `stream`, `sequence`, and `layer`.

#### **2. Parameter & Audio Hooks**
This section contains the raw configuration data and references to the actual audio files.
* **Variables:** It declares arrays for playback properties, such as `event_var_volume_rand_min` (random volume minimums), pitch adjustments, and positional fall-off distances (`pos_fall_off`, `pos_dist_max`).
* **Asset Names:** A large block of null-terminated strings pointing to the names of the raw `.rsd` audio tracks to be loaded into memory (e.g., `city_busy_loop_05`, `stadium_tunnel_loop`, `harbour_day_loop`).

#### **3. Regional Audio Logic**
The engine uses "Regions" to define continuous states of audio playback. This block maps out the logical names of these areas.
* Examples include `city_day_region`, `slum_region`, `krustylu_studios_exterior_region`, and `seaside_day_region`.
* It contains the relationship mapping between these regions (e.g., `target_region_ref`, `transition_region_ref`, `exit_region_ref`), dictating how the music or ambience crossfades when the player moves between different areas of the map.

#### **4. Level / Zone Mappings**
The final major string block explicitly connects the game's physical world zones (Stage/Level chunks and interiors) to the logical "Regions" defined above.
* **Exterior Zones:** Mappings like `L1_suburbs_day`, `L2_matlock_expressway_day`, and `L3_seaside_day`.
* **Interiors:** Mappings for specific indoor areas that trigger immediate acoustic changes, such as `L1_Kwik_E_Mart`, `L1_Stonecutters_Tunnel`, `L2_DMV`, and `L3_Krustylu_Studios`.

#### **5. File Locations & Inventory**
The following `.rms` files are packed within `.rcf` archives (Radical Cement Files) and organize music and ambience for distinct game regions and levels. Each level-stage file is structured around the four semantic blocks described above, with region and zone mappings that correspond to the game's physical geography:

**Level Music Files (within `music01_rcf\sound\music\`):**
| File | Size | Purpose |
|------|-----:|---------|
| `l1_music.rms` | 52,191 bytes | Level 1 (Suburbs) dynamic music composition and transitions |
| `l2_music.rms` | 52,609 bytes | Level 2 (Downtown/Streets) dynamic music composition and transitions |
| `l3_music.rms` | 62,157 bytes | Level 3 (Seaside/Docks) dynamic music composition and transitions |
| `l4_music.rms` | 50,708 bytes | Level 4 music composition and transitions |
| `l5_music.rms` | 45,982 bytes | Level 5 music composition and transitions |
| `l6_music.rms` | 48,379 bytes | Level 6 music composition and transitions |
| `l7_music.rms` | 48,226 bytes | Level 7 music composition and transitions |

**Ambience File (within `ambience_rcf\sound\ambience\`):**
| File | Size | Purpose |
|------|-----:|---------|
| `ambience.rms` | (variable) | Global ambience, environmental soundscapes, and background audio loops across all levels and regions |

**Serial Numbers & Organization:** The level-indexed scheme (`l1` through `l7`) suggests that each file is tied to a specific game chapter or progression stage. The separate `ambience.rms` file suggests that background soundscapes (wind, rain, traffic, urban hum) are stored and managed independently from level-specific music, allowing the engine to layer these sounds dynamically without file format duplication.

