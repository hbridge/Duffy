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
	private ArrayList<Result> imgResults;
	public ArrayList<CatSynonyms> classList;
	public String[] blackList;
	public String[] docClassList; //which classes to append docAltList to
	public String docAltWords;
	

	public WordNetNav() {
		System.setProperty("wordnet.database.dir", "/usr/local/WordNet-3.0/dict/");
		database = WordNetDatabase.getFileInstance(); 
		imgResults = new ArrayList<Result>();
		classList = new ArrayList<CatSynonyms>();
		blackList = new String[] {"physical entity", "entity", "whole", 
				"matter", "object", "abstraction", "artifact", 
				"instrumentality", "living thing", "organism", "foodstuff",
				"flavorer", "natural object", "implement", "covering", 
				"nutriment", "solid", "equipment", "contestant", "ingredient",
				"substance", "medium", "diversion", "activity", "act", "event",
				"psychological feature", "chordate", "vertebrate", 
				"invertebrate", "placental", "carnivore", "drinking vessel"};
		docClassList = new String[] {"menu", "crossword puzzle", "envelope"};
		docAltWords = new String("documents,document,docs,doc");
	}
	
	
	public void processModelOutputFile() {
		String line;
		try {
			BufferedReader br = new BufferedReader(new FileReader("/Users/aseem/Dropbox/Duffy/1k_class_test_results_1.txt"));
			try {
				line = br.readLine();

	        	while (line != null) {
	        		//imgResults.add(new Result(line));
	        		classList.add(new CatSynonyms(line));
	        		//System.out.println(imgResults.get(imgResults.size()-1));
	        		line = br.readLine();
	        	}
			} finally {
				br.close();
				System.err.println(imgResults.size() + " rows read from file!");
			}
		} catch (FileNotFoundException f) {
			System.err.println("File not found!");
			
		} catch (IOException e) {
	        System.err.println("Caught IOException: " + e.getMessage());
		}
	}
	
	public void processClassListFile() {
		String line;
		int count = 1;
		try {
			BufferedReader br = new BufferedReader(new FileReader("/Users/aseem/Dropbox/Code/workspace/WordNet/txtfiles/classlist.csv"));
			try {
				line = br.readLine(); // ignore first line of headers
				line = br.readLine();

	        	while (line != null && count <= 1000) {
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
	
	public NounSynset findAncestor(Result r){
		Synset synsetsA[], synsetsB[], synsetsC[];
		NounSynset nounSynsetA, nounSynsetB, nounSynsetC, nounSynsetAB;
		
		synsetsA = database.getSynsets(r.ccEntries.get(0).sCategory, SynsetType.NOUN);
		nounSynsetA = (NounSynset)(synsetsA[0]); 
		synsetsB = database.getSynsets(r.ccEntries.get(1).sCategory, SynsetType.NOUN);
		nounSynsetB = (NounSynset)(synsetsB[0]); 
		synsetsC = database.getSynsets(r.ccEntries.get(2).sCategory, SynsetType.NOUN);
		nounSynsetC = (NounSynset)(synsetsC[0]); 
		
		nounSynsetAB = findCommonAncestor(nounSynsetA, nounSynsetB);
		return findCommonAncestor(nounSynsetC, nounSynsetAB);
	}
	
	public NounSynset findCommonAncestor(NounSynset a, NounSynset b) {

		if (a == null || b == null) {
			return null;
		}
		
		ArrayList<NounSynset> pathA = new ArrayList<NounSynset>();
		ArrayList<NounSynset> pathB = new ArrayList<NounSynset>();
	
		// build path for a
		NounSynset nsTemp = a;
		NounSynset[] nsHypernyms;
		
		pathA.add(a);
		while (nsTemp != null) {
			nsHypernyms = nsTemp.getHypernyms();
			if (nsHypernyms.length > 0) {
				pathA.add(nsHypernyms[0]);
				nsTemp = nsHypernyms[0];
			}
			else {
				nsTemp = null;
			}
		}
		
		System.out.println("");
		for (NounSynset ns: pathA) {
			System.out.println(ns + " ->");
		}
		
		// build path for b
		nsTemp = b;
		pathB.add(b);
		while (nsTemp != null) {
			nsHypernyms = nsTemp.getHypernyms();
			if (nsHypernyms.length > 0) {
				pathB.add(nsHypernyms[0]);
				nsTemp = nsHypernyms[0];
			}
			else {
				nsTemp = null;
			}
		}
		
		
		System.out.println("");
		for (NounSynset ns: pathB) {
			System.out.println(ns + " ->");
		}

		for (NounSynset nsA: pathA) {
			for (NounSynset nsB: pathB) {
				if (nsA.getWordForms()[0].equalsIgnoreCase(nsB.getWordForms()[0])) {
					return nsA;
				}
			}
		}
		//System.err.println("NO COMMON ANCESTOR FOUND!");
		return null;
	}
	
	public void addHypernyms(CatSynonyms cs) {
		Synset synsets[] = database.getSynsets(cs.sCategory, SynsetType.NOUN);
		NounSynset ns = null; // = (NounSynset)(synsets[0]); 
		for (int i =0; i<synsets.length; i++) {
			if (synsets[i].hashCode() == cs.id) {
				ns = (NounSynset)synsets[i];
			}
		}
		if (ns == null) {
			System.err.println("Didn't find synset: " + cs.sCategory);
			System.exit(0);
		}
		//System.out.println("Class ID: " + ns.hashCode());
		
		// build path
		NounSynset[] nsHypernyms;
		NounSynset nsTemp;

		nsTemp = ns;
		while (nsTemp != null) {
			nsHypernyms = nsTemp.getHypernyms();
			if (nsHypernyms.length > 0) {
				if (!isInBlackList(nsHypernyms[0].getWordForms()[0])){
					cs.sAlternates.add(nsHypernyms[0].getWordForms()[0]);
				}
				nsTemp = nsHypernyms[0];
			}
			else {
				nsTemp = null;
			}
		}
		
		if (isADocWord(cs.sCategory)){
			cs.sAlternates.add(docAltWords);
		}
	}
	
	public boolean isInBlackList(String input){
		
		for (int i = 0; i< blackList.length; i++) {
			if (blackList[i].equalsIgnoreCase(input.toLowerCase())) {
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

	/**
	 * @param args
	 */
	public static void main(String[] args) {
		// TODO Auto-generated method stub
		System.err.println("Starting...");
		
		// initialize wordnet
		WordNetNav wn = new WordNetNav();
				
		/* original code to find the earliest common ancestor
		wn.processModelOutputFile();
		
		for (Result r: wn.imgResults) {
			r.setAncestor(wn.findAncestor(r));
			System.out.println(r);
		}
		*/
		
		// code to output a list of alternates from wordnet
		wn.processClassListFile();		
		
		for (CatSynonyms cs: wn.classList) {
			wn.addHypernyms(cs);
			System.out.println(cs);
		}
		
		System.err.println("Finished!");
	}
	
	public class Result {
		public String fileName;
		public ArrayList<CatConf> ccEntries;
		private NounSynset nsAncestor;
		
		public Result(String input){
			String splitString[] = input.split(",");
			
			fileName = splitString[0].trim();
			ccEntries = new ArrayList<CatConf>();
			for (int i = 1; i<6; i++) {	
				ccEntries.add(new CatConf(splitString[i]));
			}
			nsAncestor = null;
		}
		
		public NounSynset getAncestor(){
			return nsAncestor;
		}
		
		public void setAncestor(NounSynset ns){
			nsAncestor = ns;
		}
		
		public String toString() {
			String s = fileName + ", ";
			if (nsAncestor != null) {
				s+= "Ancestor: " + nsAncestor.getWordForms()[0] + ", ";
			}
			else {
				s+= "Ancestor: --, ";
			}
			for (CatConf cc: ccEntries) {
				s += cc.toString() + ", ";
			}
			return s;
		}
	}

	public class CatSynonyms {
		public String sCategory;
		public int id;
		public ArrayList<String> sAlternates;
		
		public CatSynonyms(String input) {
			String splitString[] = input.split("\\|");
			
			String words[] = splitString[2].split(",");
			id = Integer.parseInt(splitString[1].replace("n", ""));
			//System.out.println("class ID: " + id);
			
			sCategory = words[0];
			
			sAlternates = new ArrayList<String>();
			
			for (int i = 1; i<words.length; i++) {
				sAlternates.add(words[i].trim());
			}
		}
		
		public String toString(){
			String s = sCategory;
			for (String ns: sAlternates) {
				s += "," + ns;
			}
			return s;
		}
	}
	
	public class CatConf {	
		public String sCategory;
		public float fConfidence;
		
		public CatConf(String s, float f) {
			sCategory = s.replace('_', ' ');
			fConfidence = f;
		}
		
		public CatConf(String s) {
			String splitString[] = s.trim().split(" ");
			sCategory = splitString[0].replace('_', ' ');		
			fConfidence = Float.valueOf(splitString[1].replace('(', ' ').replace(')', ' ')).floatValue();	
		}
		
		public String toString(){
			return sCategory + " (" + fConfidence + ")";
		}
	}
}
