"""
Forest Story Generator using Coqui TTS
Generates multiple nature-themed stories with random voice selection
Install requirements.txt before using.
"""

from TTS.api import TTS
import random
import os
from datetime import datetime
import json
import sys
import time
import subprocess

# Vocabulary for nature stories
activities = [
    "hiking", "camping", "exploring", "birdwatching", "fishing", 
    "foraging", "photographing wildlife", "stargazing", "tracking animals",
    "meditating", "painting landscapes", "writing in my journal", "collecting rocks",
    "identifying plants", "building a shelter", "canoeing", "rock climbing"
]

locations = [
    "ancient redwood forest", "mountain trail", "secluded alpine lake", 
    "dense pine woods", "sun-dappled meadow", "misty river valley",
    "hidden waterfall grotto", "old growth forest", "moss-covered canyon",
    "wildflower-filled clearing", "rocky mountain summit", "serene forest pond",
    "babbling brook side", "oak tree grove", "birch tree forest", "cedar woodland"
]

sensory_details = [
    "the earthy scent of damp soil and decaying leaves filling my nostrils",
    "the symphony of birdsong echoing through the canopy above me",
    "the cool, refreshing mist from the waterfall kissing my face",
    "the warm golden sunlight filtering through the emerald green leaves",
    "the satisfying crunch of autumn leaves under my hiking boots",
    "the gentle whisper of wind dancing through the pine needles",
    "the sweet fragrance of wildflowers carried on the afternoon breeze",
    "the crisp, clean mountain air filling my lungs with each breath",
    "the distant rumble of thunder promising a summer storm",
    "the melodic babbling of the stream composing nature's music",
    "the damp, rich smell of moss and fungi on fallen logs",
    "the electric silence broken only by my own heartbeat"
]

actions = [
    "sat silently", "walked leisurely", "rested contemplatively", "watched intently", 
    "listened carefully", "wandered aimlessly", "explored curiously", "waited patiently",
    "observed keenly", "sketched quickly", "photographed diligently", "meditated deeply",
    "napped peacefully", "reflected thoughtfully", "prayed gratefully", "dreamed wistfully"
]

natural_features = [
    "cascading waterfall", "crystal-clear river", "ancient oak tree", "sheer cliff face",
    "sunny clearing", "hidden cave", "eagle's nest", "beaver dam", "berry patch",
    "animal trail", "rock formation", "natural spring", "wildflower field",
    "fallen giant sequoia", "owl's perch", "deer crossing"
]

specific_moments = [
    "that breathtaking sunset over the mountains", "the unexpected eagle sighting",
    "the sudden summer storm passing through", "discovering the hidden animal path",
    "witnessing the birth of a fawn", "the meteor shower in the clear night sky",
    "finding the abandoned bird's nest", "the encounter with the curious fox",
    "the morning when frost painted everything silver", "the autumn colors explosion",
    "the silent snowfall blanketing the forest", "the first spring buds appearing"
]

environments = [
    "deep forest", "snow-capped mountains", "peaceful valley", "untamed wilderness",
    "national park", "protected reserve", "remote backcountry", "ancient woodland",
    "coastal rainforest", "alpine meadow", "river delta", "canyon lands",
    "old growth ecosystem", "biodiversity hotspot", "conservation area"
]

emotional_details = [
    "feeling completely at peace with the world", "overwhelmed by nature's raw beauty",
    "connected to something greater than myself", "humbled by the ancient trees",
    "filled with childlike wonder and excitement", "completely present in the moment",
    "washed clean of all urban stress and worries", "reconnected with my primal self",
    "inspired by the resilience of nature", "grateful for this moment of solitude",
    "awestruck by the intricate web of life", "rejuvenated in mind, body, and spirit"
]

memory_details = [
    "watching the stars gradually appear in the twilight sky",
    "listening to the owls begin their nocturnal conversations",
    "feeling the cool evening breeze whisper through the trees",
    "smelling the wood smoke from my campfire mixing with pine",
    "tasting the fresh wild berries I had gathered earlier",
    "hearing the distant howl of a lone wolf echoing through the valley",
    "witnessing the dance of fireflies creating living constellations",
    "feeling the first drops of rain on my outstretched hand",
    "watching the moon rise over the silhouette of distant peaks",
    "hearing the crackle of frost underfoot in the morning stillness"
]

# Story templates
templates = [
    "I remember {activity} in the {location}, {sensory_detail}.",
    "There was this magical time I {action} near the {natural_feature}, {memory_detail}.",
    "I'll never forget {specific_moment} in the {environment}, {emotional_detail}.",
    "One summer afternoon, while {activity}, I experienced {specific_moment} that left me {emotional_detail}.",
    "The memory of {action} by the {natural_feature} remains vivid in my mind, {sensory_detail}.",
    "I often think back to that day in the {location} when {specific_moment} happened, {emotional_detail}.",
    "While {activity} through the {environment}, I encountered {specific_moment} and felt {emotional_detail}."
]

PROBLEMATIC_MODELS = [
    "tts_models/en/ek1/tacotron2",
]

MULTI_SPEAKER_MODELS = [
    "tts_models/en/vctk/vits",
]

VOICE_MODELS = {
    "male": [
        "tts_models/en/ljspeech/tacotron2-DDC",
        "tts_models/en/ljspeech/glow-tts",
        "tts_models/en/vctk/vits",
        "tts_models/en/blizzard2013/capacitron-t2-c150_v2"
    ],
    "female": [
        "tts_models/en/ljspeech/tacotron2-DDC",
        "tts_models/en/ljspeech/glow-tts",
        "tts_models/en/vctk/vits",
        "tts_models/en/blizzard2013/capacitron-t2-c150_v2"
    ],
    "any": [
        "tts_models/en/ljspeech/tacotron2-DDC",
        "tts_models/en/ljspeech/glow-tts",
        "tts_models/en/vctk/vits",
        "tts_models/en/blizzard2013/capacitron-t2-c150_v2"
    ]
}

current_tts = None
current_model = None

def setup_espeak_environment():
    """Set up environment for espeak if found"""
    common_paths = [
        r"C:\Program Files\eSpeak\command_line\espeak.exe",
        r"C:\Program Files (x86)\eSpeak\command_line\espeak.exe",
    ]
    
    for path in common_paths:
        if os.path.exists(path):
            espeak_dir = os.path.dirname(path)
            os.environ['PATH'] = espeak_dir + ';' + os.environ.get('PATH', '')
            print(f"✓ Found espeak at: {path}")
            return True
    
    print("⚠ espeak not found in common locations")
    return False

def generate_random_story():
    template = random.choice(templates)
    return template.format(
        activity=random.choice(activities),
        location=random.choice(locations),
        sensory_detail=random.choice(sensory_details),
        action=random.choice(actions),
        natural_feature=random.choice(natural_features),
        specific_moment=random.choice(specific_moments),
        environment=random.choice(environments),
        emotional_detail=random.choice(emotional_details),
        memory_detail=random.choice(memory_details)
    )

def get_random_voice_model(gender_preference="any"):
    if gender_preference in VOICE_MODELS:
        return random.choice(VOICE_MODELS[gender_preference])
    else:
        return random.choice(VOICE_MODELS["any"])

def get_random_speaker(model_name):
    """Get a random speaker for multi-speaker models"""
    if model_name == "tts_models/en/vctk/vits":
        return f"p{random.randint(225, 376)}"
    return None

def initialize_tts(model_name, use_gpu=False):
    global current_tts, current_model
    
    if model_name in PROBLEMATIC_MODELS:
        print(f"Skipping problematic model: {model_name}")
        return None
    
    if current_model == model_name and current_tts is not None:
        return current_tts
    
    try:
        print(f" > Initializing TTS with model: {model_name}")
        current_tts = TTS(model_name=model_name, progress_bar=True, gpu=use_gpu)
        current_model = model_name
        return current_tts
    except Exception as e:
        print(f"Error initializing model {model_name}: {e}")
        
        if "weights_only" in str(e) or "RAdam" in str(e):
            print(f"Adding {model_name} to problematic models list")
            if model_name not in PROBLEMATIC_MODELS:
                PROBLEMATIC_MODELS.append(model_name)
        
        return None

def generate_stories(num_stories=5, gender="any", output_dir=None, use_gpu=False):
    global current_tts, current_model
    
    if output_dir is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_dir = f"forest_stories_{timestamp}"
    else:
        os.makedirs(output_dir, exist_ok=True)
    
    os.makedirs(output_dir, exist_ok=True)
    stories_data = []
    
    print(f"\n{'='*80}")
    print(f"Generating {num_stories} forest stories with {gender} voices")
    print(f"Output directory: {output_dir}")
    print(f"{'='*80}")
    
    setup_espeak_environment()
    
    # Pre-selection of models
    selected_models = []
    for _ in range(num_stories):
        model = get_random_voice_model(gender)
        while model in PROBLEMATIC_MODELS:
            model = get_random_voice_model(gender)
        selected_models.append(model)
    
    for i in range(num_stories):
        story = generate_random_story()
        model_name = selected_models[i]
        
        print(f"\nStory {i+1}/{num_stories}:")
        print(f"Voice model: {model_name}")
        print(f"Story: {story}")
        print(f"{'-'*60}")
        
        try:
            tts = initialize_tts(model_name, use_gpu)
            if tts is None:
                print(f"Skipped story {i+1} due to model error")
                continue
            
            filename = f"forest_story_{i+1}.wav"
            filepath = os.path.join(output_dir, filename)
            
            try:
                # NEW: Handle multi-speaker models
                if model_name in MULTI_SPEAKER_MODELS:
                    speaker = get_random_speaker(model_name)
                    if speaker:
                        print(f" > Using speaker: {speaker}")
                        tts.tts_to_file(text=story, file_path=filepath, speaker=speaker)
                    else:
                        tts.tts_to_file(text=story, file_path=filepath)
                else:
                    tts.tts_to_file(text=story, file_path=filepath)
                    
            except Exception as e:
                if "speaker" in str(e).lower() and model_name not in MULTI_SPEAKER_MODELS:
                    print(f"Model {model_name} is multi-speaker")
                    MULTI_SPEAKER_MODELS.append(model_name)
                    speaker = get_random_speaker(model_name)
                    if speaker:
                        print(f" > Retrying with speaker: {speaker}")
                        tts.tts_to_file(text=story, file_path=filepath, speaker=speaker)
                    else:
                        print(f"Could not determine speaker for model {model_name}")
                        continue
                else:
                    print(f"Error generating story {i+1}: {e}")
                    current_tts = None
                    current_model = None
                    continue
            
            # Metadata
            stories_data.append({
                'filename': filename,
                'model': model_name,
                'story_text': story,
                'gender': gender
            })
            
            print(f"Saved: {filename}")
            time.sleep(1)
            
        except Exception as e:
            print(f"Error generating story {i+1}: {str(e)}")
            current_tts = None
            current_model = None
            continue
    
    # Metadata text file
    if stories_data:
        metadata_file = os.path.join(output_dir, "stories_metadata.txt")
        with open(metadata_file, 'w', encoding='utf-8') as f:
            f.write("Forest Stories Metadata\n")
            f.write("=" * 50 + "\n\n")
            # NEW: Add compatibility info to metadata
            f.write(f"Output directory: {output_dir}\n")
            if PROBLEMATIC_MODELS:
                f.write(f"Skipped models (PyTorch 2.6 issues): {', '.join(PROBLEMATIC_MODELS)}\n")
            if MULTI_SPEAKER_MODELS:
                f.write(f"Multi-speaker models used: {', '.join(MULTI_SPEAKER_MODELS)}\n")
            f.write("\n")
            
            for i, data in enumerate(stories_data, 1):
                f.write(f"Story {i}:\n")
                f.write(f"File: {data['filename']}\n")
                f.write(f"Model: {data['model']}\n")
                f.write(f"Gender: {data['gender']}\n")
                f.write(f"Text: {data['story_text']}\n")
                f.write("-" * 50 + "\n\n")
        
        print(f"\n✓ Generated {len(stories_data)} stories out of {num_stories} requested")
        print(f"Metadata saved to: {metadata_file}")
        
        if PROBLEMATIC_MODELS:
            print(f"Skipped {len(PROBLEMATIC_MODELS)} models, PyTorch 2.6 compatibility issues")
    else:
        print(f"\nFailed to generate any stories")
    
    # Clean up
    current_tts = None
    current_model = None
    return stories_data

def list_models():
    print("Available voice models by gender:")
    print("=" * 50)
    for gender, models in VOICE_MODELS.items():
        print(f"\n{gender.upper()} voices:")
        for model in models:
            status = "Works" if model not in PROBLEMATIC_MODELS else "(PyTorch 2.6 issue)"
            speaker_info = " [multi-speaker]" if model in MULTI_SPEAKER_MODELS else ""
            print(f"  {status} {model}{speaker_info}")
    
    if PROBLEMATIC_MODELS:
        print(f"\nModels with PyTorch 2.6 compatibility issues:")
        for model in PROBLEMATIC_MODELS:
            print(f" Problem {model}")

# Config
def load_config():
    config = {
        "num_stories": 5,
        "gender": "any",
        "output_dir": None,
        "use_gpu": False
    }
    
    if os.path.exists("config.json"):
        try:
            with open("config.json", "r") as f:
                user_config = json.load(f)
                config.update(user_config)
        except:
            print("Warning: Error reading config.json, using default settings")
    
    return config

def main():
    config = load_config()
    
    command = sys.argv[1].lower()
    
    if command == "list":
        list_models()
    
    elif command == "generate":
        num_stories = config["num_stories"]
        gender = config["gender"]
        use_gpu = config["use_gpu"]
        output_dir = config["output_dir"]
        
        args = sys.argv[2:]
        i = 0
        while i < len(args):
            if args[i].isdigit():
                num_stories = int(args[i])
            elif args[i] in ["male", "female", "any"]:
                gender = args[i]
            elif args[i] == "gpu":
                use_gpu = True
            elif args[i] == "output" and i + 1 < len(args):
                output_dir = args[i + 1]
                i += 1
            i += 1
        
        stories = generate_stories(
            num_stories=num_stories,
            gender=gender,
            output_dir=output_dir,
            use_gpu=use_gpu
        )
        
        if stories:
            print(f"\nSuccessfully generated {len(stories)} stories")
            print(f"Output directory: {os.path.abspath(output_dir)}")
    
    else:
        print(f"Error: Unknown command '{command}'")

if __name__ == "__main__":
    main()