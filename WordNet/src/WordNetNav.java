import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;

import edu.smu.tspell.wordnet.NounSynset;
import edu.smu.tspell.wordnet.Synset;
import edu.smu.tspell.wordnet.SynsetType;
import edu.smu.tspell.wordnet.WordNetDatabase;


public class WordNetNav {
	
	private WordNetDatabase database;
	public ArrayList<CatSynonyms> classList;
	public String[] whiteList, 
					wlAnimals, 
					wlFoods, 
					wlFurniture, 
					wlMusicalInstruments,
					wlObjects,
					wlOutdoors,
					wlPlants,
					wlStructures,
					wlVehicles;
	public String[] docClassList; //which classes to append docAltList to
	public String docAltWords;
	public String[] swapIn; //list of words that exist in Wordnet
	public String[] swapOut; // list of words to swap them with using the same index
	

	public WordNetNav() {
		System.setProperty("wordnet.database.dir", "/usr/local/WordNet-3.0/dict/");
		//System.setProperty("wordnet.db.dir", "/usr/local/WordNet-3.0/");
		database = WordNetDatabase.getFileInstance(); 
		classList = new ArrayList<CatSynonyms>();

		docClassList = new String[] {"menu", "crossword puzzle", "envelope"};
		docAltWords = new String("documents,document,docs,doc");
		
		/* Only these whitelisted words make it through to the search index */

		wlAnimals = new String[] {"animal", "dog", "whale", "panda", "cat", 
					"dolphin", "elephant", "monkey", "horse", "ape", "camel", "pig",
					"fox", "bear", "rabbit", "hippo", "lion", "tiger", "cheetah", 
					"zebra", "insect", "starfish", "bird", "ostrich", "finch", 
					"robin", "nightingale", "jay", "magpie", "hawk", "eagle",
					"owl", "peacock", "quail", "parrot", "cuckoo", "hummingbird",
					"duck", "goose", "swan", "stork", "flamingo", "heron", 
					"crane", "pelican", "penguin", "albatross", "shark", "fish",
					"ray", "stingray", "salmon", "eel", "sturgeon", "turtle",
					"gecko", "lizard", "iguana", "dinosaur", "crocodile",
					"alligator", "snake", "boa", "python", "cobra", "mamba",
					"salamander", "frog", "scorpion", "spider", "crab", 
					"lobster", "crawfish", "beetle", "butterfly", "jellyfish",
					"anemone", "worm"};

		wlFoods = new String[] {"food", "fruit", "strawberry", "apple", 
					"orange", "lemon", "fig", "pineapple", "banana", "jackfruit",
					"pomegranate", "acorn", "grain", "potato", "cabbage", "vegetable",
					"cauliflower", "zucchini", "squash", "cucumber", "mushroom",
					"stew", "bread", "dessert", "wine", "alcohol", "punch", "coffee",
					"pizza", "ice cream", "icecream", "hamburger", "sandwich"};

		wlFurniture = new String[] {"furniture", "bed", "bookcase",
					"cabinet", "lamp", "bench", "seat", "chair", "sofa", "desk", 
					"table", "pool table", "dining table", "entertainment center",
					"closet"};

		wlMusicalInstruments = new String[] {"musical instrument", "pipe organ", "gong", "drum",
					"cello", "violin", "harp", "guitar", "trumpet", "horn", "brass",
					"harp", "harmonica", "oboe", "sax", "flute", "piano"};

		wlObjects = new String[] {"gun", "umbrella", "ball", "laptop", "computer",
					"hatchet", "ax", "knife", "cleaver", "tool", "power drill",
					"mower", "hammer", "bottle opener", "can opener", "plunger",
					"screwdriver", "shovel", "plow", "chainsaw", "brush",
					"hair dryer", "speaker", "screen", "display", "mouse",
					"fan", "heater", "stove", "instrument", "scale", "clock",
					"hourglass", "sundial", "timer", "watch", "compass", 
					"syringe", "binoculars", "sunglasses", "telescope",
					"bow", "keyboard","crane", "calculator", "atm", "notebook",
					"website", "printer", "switch", "wheel", "disk", "plate",
					"sunglass", "mirror", "remote", "brake", "clip", "knot",
					"lock", "nail", "pin", "screw", "seatbelt", "ski", "candle",
					"torch", "rack", "trap", "web", "iron", "coffee maker", 
					"appliance", "microwave", "oven", "toaster", "vacuum", 
					"dishwasher", "refrigerator", "pan", "pot", "spatula", "grille",
					"door", "fence", "gate", "board", "rack", "curtain", "jean",
					"box", "shoe", "trash can", "necklace", "jewelry", "coat",
					"pajama", "rug", "robe", "jug", "mask", "bottle", "helmet",
					"roof", "dish", "cap", "teddy bear", "photocopier", "gown",
					"crossword", "suit", "skirt", "glass", "bag", "bowl", "sweater",
					"backpack", "camera", "racket", "traffic light", "pen",
					"hat", "bus", "tub","dress", "cellphone", "boot", "package",
					"pole", "wallet", "magazine", "sign", "purse", "television",
					"swimsuit", "spoon", "t-shirt", "puzzle", "game", "mat",
					"bikini", "sock", "mug"};

		wlOutdoors = new String[] {"cliff", "valley", "mountain", "volcano", "ridge",
					"reef", "lakeshore", "shore", "coast", "geyser", "spring"};

		wlPlants = new String[] {"flower", "plant", "daisy", "orchid"};

		wlStructures = new String[] {"altar", "arch", "patio", "bridge", "building", 
					"greenhouse", "house", "palace", "monastery", "shed", "church", 
					"mosque", "restaurant", "cinema", "movie theater", "home theater",
					"column", "prison", "grocery", "bookstore", "butcher shop",
					"candy store", "shoe store", "fountain", "dock", "memorial", 
					"dam", "tent", "pedestal", "lighthouse", "beacon", "water tower"};

		wlVehicles = new String[] {"airplane", "spacecraft", "boat",
					"sailboat", "ship", "tank", "rocket", "bicycle", "car", "scooter",
					"locomotive", "minivan", "motorcycle", "truck", "van", "RV", "tram",
					"tractor", "trailer", "tricycle", "unicycle", "cart", "wagon",
					"train"};
		
		/* Words in swapIn are replaced with equivalent word from swapOut */

		swapIn = new String[] {"sailing vessel", "military plane", "steel drum", 
					"hard disk", "hermit crab", "refrigerator", "telephone",
					"television", "hamburger"};
		swapOut = new String[] {"sailboat", "airplane", "drum", 
					"disk", "crab", "fridge", "phone",
					"tv", "burger"};

		whiteList =  merge(wlAnimals, 
							wlFoods, 
							wlFurniture, 
							wlMusicalInstruments, 
							wlObjects, 
							wlOutdoors, 
							wlPlants, 
							wlStructures, 
							wlVehicles);

		System.err.println("WhiteList length: " + whiteList.length);
	}

	/**
	 * This method merges any number of arrays of any count.
	 */

	public static String[] merge(String[]... arrays) {
	    // Count the number of arrays passed for merging and the total size of resulting array
	    int arrCount = 0;
	    int count = 0;
	    for (String[] array: arrays) {
	     	arrCount++;
	     	count += array.length;
	    }

	    // Create new array and copy all array contents
	    String[] mergedArray = (String[]) java.lang.reflect.Array.newInstance(arrays[0][0].getClass(), count);
	    int start = 0;
	    for (String[] array: arrays) {
	      System.arraycopy(array, 0, mergedArray, start, array.length);
	      start += array.length;
	    }
	    return mergedArray;
  	}
	
	public void processClassListFile(int lineCount) {
		String line;
		int count = 1;
		try {
			BufferedReader br = new BufferedReader(new FileReader("txtfiles/classlist.csv"));
			try {
				line = br.readLine(); // ignore first line of headers
				line = br.readLine();

	        	while (line != null && count <= lineCount) {
	        		classList.add(new CatSynonyms(line));
	        		count++;
	        		line = br.readLine();
	        		
	        	}
			} finally {
				br.close();
				System.err.println(classList.size() + " rows read from file!");
			}
		} catch (FileNotFoundException f) {
			System.err.println("File not found!");
			
		} catch (IOException e) {
	        System.err.println("Caught IOException: " + e.getMessage());
		}
	}
	
	public void addHypernyms(CatSynonyms cs) {
		Synset synsets[] = database.getSynsets(cs.sCategory, SynsetType.NOUN);
		NounSynset ns = null; // = (NounSynset)(synsets[0]); 
		for (int i =0; i<synsets.length; i++) {
			if (synsets[i].hashCode() == cs.id) {
				ns = (NounSynset)synsets[i];
				break;
			}
		}
		if (ns == null) {
			System.err.println("Didn't find synset: " + cs.sCategory);
			System.exit(0);
		}
		
		NounSynset[] nsHypernyms;
		NounSynset nsTemp;
		String sTemp;

		nsTemp = ns;
		while (nsTemp != null) {
			nsHypernyms = nsTemp.getHypernyms();
			if (nsHypernyms.length > 0) {
				if (isInWhiteList(nsHypernyms[0].getWordForms()[0])){
					cs.sOutputTerms.add(nsHypernyms[0].getWordForms()[0]);
				}
				sTemp = findSwap(nsHypernyms[0].getWordForms()[0]);
				if (sTemp.length()>0){
					cs.sOutputTerms.add(sTemp);
				}
				nsTemp = nsHypernyms[0];
			}
			else {
				nsTemp = null;
			}
		}
		
		if (isADocWord(cs.sCategory)){
			cs.sOutputTerms.add(docAltWords);
		}
	}

	public boolean isInWhiteList(String input){
		
		for (int i = 0; i< whiteList.length; i++) {
			if (whiteList[i].equalsIgnoreCase(input.toLowerCase())) {
				return true;
			}
		}
		return false;
	}
	
	public boolean isADocWord(String input) {
		for (int i = 0; i< docClassList.length; i++) {
			if (docClassList[i].equalsIgnoreCase(input.toLowerCase())) {
				return true;
			}
		}
		return false;
	}

	public String findSwap(String input) {
		for (int i = 0; i< swapIn.length; i++) {
			if (swapIn[i].equalsIgnoreCase(input.toLowerCase())) {
				return swapOut[i];
			}
		}
		return "";
	}


	/**
	 * @param args
	 */
	public static void main(String[] args) {
		System.err.println("Starting...");
		
		// initialize wordnet
		WordNetNav wn = new WordNetNav();		
		
		// Read in the first 1000 lines of the class list
		wn.processClassListFile(1000);		
		
		// For each item look up hierarchy in Wordnet and 
		// add to alt terms based on whitelist
		for (CatSynonyms cs: wn.classList) {
			wn.addHypernyms(cs);
			System.out.println(cs);
		}
		
		System.err.println("Finished!");
	}

	public class CatSynonyms {
		public String sCategory;
		public int id;
		public ArrayList<String> sOutputTerms;
		
		public CatSynonyms(String input) {
			String splitString[] = input.split("\\|");
			
			String words[] = splitString[2].split(",");
			id = Integer.parseInt(splitString[1].replace("n", ""));
			
			sCategory = words[0];
			
			sOutputTerms = new ArrayList<String>();
			
			String sTemp;
			for (int i = 0; i<words.length; i++) {
				if (isInWhiteList(words[i])){
					sOutputTerms.add(words[i].trim());
				}
				sTemp = findSwap(words[i].trim());
				if (sTemp.length()>0){
					sOutputTerms.add(sTemp);
				}
			}
			
		}
		
		public String toString(){
			String s = sCategory;
			for (String ns: sOutputTerms) {
				s += "," + ns;
			}
			return s;
		}
	}
}
