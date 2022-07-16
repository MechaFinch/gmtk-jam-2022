package gmtkloader;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;

import asmlib.util.relocation.RelocatableObject;
import asmlib.util.relocation.RelocatableObject.Endianness;

/**
 * Converts twine-esque files into RelocatableObjects for maximum swag
 * 
 * @author Mechafinch
 */
public class GMTKJamConverter {
    
    public static void main(String[] args) throws IOException {
        String fn = args[0];
        File fileIn = new File(fn),
             fileOut = new File(fn.substring(0, fn.lastIndexOf(".")) + ".obj");
        
        RelocatableObject obj = convert(Files.readAllLines(fileIn.toPath()));
        
        // write file
        try(FileOutputStream fos = new FileOutputStream(fileOut)) {
            fos.write(obj.asObjectFile());
        }
    }
    
    private static final String PREFIX_TITLE = "::",
                                PREFIX_CHOICE = "[[",
                                POSTFIX_CHOICE = "]]",
                                PREFIX_FUNCTION = "<<",
                                PREFIX_COMMENT = "//",
                                LIBRARY_NAME = "dialog";
    
    /*
     * Object Format
     * 2 byte length of description
     * 4 byte description reference
     * 
     * 1 byte number of choices
     * 
     * for each choice
     * 2 byte length of text
     * 4 byte text reference
     * 4 byte choice reference
     * 
     * 1 byte number of function calls
     * 
     * for each call,
     * 4 byte function reference
     */
    
    /**
     * Convert to relocatable object
     * 
     * @param lines
     * @return
     */
    private static RelocatableObject convert(List<String> lines) {
        HashMap<String, List<Integer>> incomingReferences = new HashMap<>();
        HashMap<String, Integer> outgoingReferences = new HashMap<>(),
                                 incomingReferenceWidths = new HashMap<>(),
                                 outgoingReferenceWidths = new HashMap<>();
        
        List<Byte> mainCode = new LinkedList<>(),
                   headerCode = new LinkedList<>();
        
        // current header
        String title = "";
        String description = "";
        List<String> choiceTextReferences = new LinkedList<>(),
                     choiceTitleReferences = new LinkedList<>(),
                     functionCalls = new LinkedList<>();
        Map<String, Integer> choiceLengths = new HashMap<>();
        
        for(int i = 0; i < lines.size(); i++) {
            String ln = lines.get(i).strip();
            
            if(ln.startsWith(PREFIX_TITLE)) {
                // title
                // write previous description
                outgoingReferences.put(title + "_ref_d", mainCode.size());
                outgoingReferenceWidths.put(title + "_ref_d", 4);
                
                byte[] bytes = description.strip().getBytes();
                for(int j = 0; j < bytes.length; j++) {
                    mainCode.add(bytes[j]);
                }
                
                // write previous header 
                if(!title.equals("")) writeHeader(headerCode, title + "_ref_d", bytes.length, choiceTextReferences, choiceLengths, choiceTitleReferences, functionCalls, incomingReferences, incomingReferenceWidths);
                choiceTextReferences = new LinkedList<>();
                choiceTitleReferences = new LinkedList<>();
                functionCalls = new LinkedList<>();
                description = "";
                
                // create reference with title's hash
                title = hashTitle(ln.substring(PREFIX_TITLE.length()));
                
                outgoingReferences.put(title, headerCode.size());
                outgoingReferenceWidths.put(title, 4);
            } else if(ln.startsWith(PREFIX_CHOICE)) {
                // choice
                String choiceReference = ln.substring(PREFIX_CHOICE.length(), ln.indexOf(POSTFIX_CHOICE)),
                       choiceText = ln.substring(ln.indexOf(POSTFIX_CHOICE) + POSTFIX_CHOICE.length());
                byte[] bytes = choiceText.strip().getBytes();
                
                choiceReference = hashTitle(choiceReference);
                
                // create code-area reference with <title hash>_ref_c<ID>
                String refName = title + "_ref_c" + choiceTextReferences.size();
                outgoingReferences.put(refName, mainCode.size());
                outgoingReferenceWidths.put(refName, 4);
                
                // add to header
                choiceTextReferences.add(refName);
                choiceLengths.put(refName, bytes.length);
                
                choiceTitleReferences.add(choiceReference);
                
                // add actual text
                for(int j = 0; j < bytes.length; j++) {
                    mainCode.add(bytes[j]);
                }
            } else if(ln.startsWith(PREFIX_FUNCTION)) {
                // function call
                functionCalls.add(ln.substring(PREFIX_FUNCTION.length()));
            } else if(ln.startsWith(PREFIX_COMMENT)) {
                // skip
            } else {
                // description
                if(!ln.equals("")) {
                    description += lines.get(i).replace("\\n", "\n") + "\n";
                }
            }
        }
        
        // write final description
        outgoingReferences.put(title + "_ref_d", mainCode.size());
        outgoingReferenceWidths.put(title + "_ref_d", 4);
        
        byte[] bytes = description.strip().getBytes();
        for(int j = 0; j < bytes.length; j++) {
            mainCode.add(bytes[j]);
        }
        
        // write final header
        writeHeader(headerCode, title + "_ref_d", bytes.length, choiceTextReferences, choiceLengths, choiceTitleReferences, functionCalls, incomingReferences, incomingReferenceWidths);
        
        // correct code area references
        for(String k : outgoingReferences.keySet()) {
            if(k.matches(".+((_ref_d)|(_ref_c[0-9]+))")) {
                outgoingReferences.put(k, outgoingReferences.get(k) + headerCode.size());
            }
        }
        
        // root symbol
        outgoingReferences.put("root", 0);
        outgoingReferenceWidths.put("root", 4);
        
        // write code array
        byte[] objectCode = new byte[headerCode.size() + mainCode.size()];
        
        for(int i = 0; i < headerCode.size(); i++) {
            objectCode[i] = headerCode.get(i);
        }
        
        for(int i = 0, j = headerCode.size(); i < mainCode.size(); i++, j++) {
            objectCode[j] = mainCode.get(i);
        }
        
        return new RelocatableObject(Endianness.LITTLE, LIBRARY_NAME, 2, incomingReferences, outgoingReferences, incomingReferenceWidths, outgoingReferenceWidths, objectCode, false);
    }
    
    /**
     * Writes a header as described above
     * 
     * @param code
     * @param descriptionReference
     * @param descriptionLength
     * @param choiceTextReferences
     * @param choiceLengths
     * @param choiceTitleReferences
     * @param functionCalls
     * @param incomingReferences
     * @param incomingReferenceWidths
     */
    private static void writeHeader(List<Byte> code, String descriptionReference, int descriptionLength, List<String> choiceTextReferences, Map<String, Integer> choiceLengths, List<String> choiceTitleReferences, List<String> functionCalls, HashMap<String, List<Integer>> incomingReferences, HashMap<String, Integer> incomingReferenceWidths) {
        // description length
        int len = descriptionLength;
        code.add((byte)(len & 0xFF));
        code.add((byte)((len >> 8) & 0xFF));
        
        // description reference
        addIncomingReference(incomingReferences, incomingReferenceWidths, descriptionReference, code.size());
        
        code.add((byte) 0);
        code.add((byte) 0);
        code.add((byte) 0);
        code.add((byte) 0);
        
        // number of choices
        code.add((byte) choiceTextReferences.size());
        
        // choices
        for(int i = 0; i < choiceTextReferences.size(); i++) {
            // length
            String textRef = choiceTextReferences.get(i),
                   titleRef = choiceTitleReferences.get(i);
            len = choiceLengths.get(textRef);
            
            code.add((byte)(len & 0xFF));
            code.add((byte)((len >> 8) & 0xFF));
            
            // text reference
            addIncomingReference(incomingReferences, incomingReferenceWidths, textRef, code.size());
            
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            
            // choice reference
            addIncomingReference(incomingReferences, incomingReferenceWidths, titleRef, code.size());
            
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
        }
        
        // number of function calls
        code.add((byte) functionCalls.size());
        
        // calls
        for(int i = 0; i < functionCalls.size(); i++) {
            addIncomingReference(incomingReferences, incomingReferenceWidths, functionCalls.get(i), code.size());
            
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
        }
    }
    
    /**
     * Adds an incoming reference
     * 
     * @param incomingReferences
     * @param ref
     * @param addr
     */
    private static void addIncomingReference(HashMap<String, List<Integer>> incomingReferences, HashMap<String, Integer> incomingReferenceWidths, String ref, int addr) {
        ref = LIBRARY_NAME + "." + ref;
        if(incomingReferences.containsKey(ref)) {
            incomingReferences.get(ref).add(addr);
        } else {
            List<Integer> addresses = new LinkedList<>();
            addresses.add(addr);
            incomingReferences.put(ref, addresses);
            incomingReferenceWidths.put(ref, 4);
        }
    }
    
    /**
     * Hashes a title to convert its name to be reference-friendly
     * @param title
     * @return
     */
    private static String hashTitle(String title) {
        return title.toLowerCase().strip().replace(' ', '_');
    }
}
