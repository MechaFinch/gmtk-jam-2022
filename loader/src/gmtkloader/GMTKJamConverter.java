package gmtkloader;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
                                PREFIX_FUNCTION = ">>",
                                PREFIX_COMMENT = "//",
                                MARKER_END = "<<",
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
     * 1 byte number of arguments
     * n 4 byte argument references
     */
    
    private static final Pattern namedColorPattern = Pattern.compile("&[wctdi]");
    
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
        
        Map<String, String> colorMap = new HashMap<>();
        
        colorMap.put("w", "&FF"); // description/default
        colorMap.put("c", "&FB"); // choice
        colorMap.put("t", "&6F"); // thought
        colorMap.put("d", "&30"); // data
        colorMap.put("i", "&C2"); // instruction
        
        // current header
        String title = "";
        String description = "";
        List<String> choiceTextReferences = new LinkedList<>(),
                     choiceTitleReferences = new LinkedList<>();
        List<List<String>> functionCalls = new LinkedList<>();
        Map<String, Integer> choiceLengths = new HashMap<>();
        int argStringCount = 0;
        
        boolean nodeHasCommands = false;
        
        for(int i = 0; i < lines.size(); i++) {
            String ln = lines.get(i).stripTrailing();
            
            Matcher m = namedColorPattern.matcher(ln);
            
            while(m.find()) {
                int j = m.start();
                ln = ln.substring(0, j) + colorMap.get("" + ln.charAt(j + 1)) + ln.substring(j + 2);
                m = namedColorPattern.matcher(ln);
            }
            
            //System.out.println(ln);
            
            if(ln.startsWith(PREFIX_TITLE)) {
                // title
                // write previous description
                outgoingReferences.put(title + "_ref_d", mainCode.size());
                outgoingReferenceWidths.put(title + "_ref_d", 4);
                
                //if(description.endsWith("\n")) description = description.substring(0, description.length() - 1);
                byte[] bytes = description.getBytes();
                for(int j = 0; j < bytes.length; j++) {
                    mainCode.add(bytes[j]);
                }
                
                // write previous header 
                if(!title.equals("")) writeHeader(headerCode, title + "_ref_d", bytes.length, choiceTextReferences, choiceLengths, choiceTitleReferences, functionCalls, incomingReferences, incomingReferenceWidths);
                choiceTextReferences = new LinkedList<>();
                choiceTitleReferences = new LinkedList<>();
                functionCalls = new LinkedList<>();
                description = "";
                nodeHasCommands = false;
                argStringCount = 0;
                
                // create reference with title's hash
                title = hashTitle(ln.substring(PREFIX_TITLE.length()));
                
                outgoingReferences.put(title, headerCode.size());
                outgoingReferenceWidths.put(title, 4);
            } else if(ln.startsWith(PREFIX_CHOICE)) {
                // choice
                String choiceReference = ln.substring(PREFIX_CHOICE.length(), ln.indexOf(POSTFIX_CHOICE)),
                       choiceText = ((choiceTextReferences.size() + 1) % 10) + ". " + ln.substring(ln.indexOf(POSTFIX_CHOICE) + POSTFIX_CHOICE.length()).strip().replace("\\n", "\n");
                byte[] bytes = choiceText.getBytes();
                
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
                
                nodeHasCommands = true;
            } else if(ln.startsWith(PREFIX_FUNCTION)) {
                // function call
                String functionName = ln.substring(PREFIX_FUNCTION.length(), ln.indexOf('('));
                String args = ln.substring(ln.indexOf('(') + 1, ln.indexOf(')'));
                
                List<String> call = new LinkedList<>();
                call.add(functionName);
                
                while(args.length() > 0) {
                    int ind = args.indexOf(',');
                    String a = "";
                    
                    if(ind == -1) {
                        // last
                        a = args.strip();
                        args = "";
                    } else {
                        a = args.substring(0, ind).strip();
                        args = args.substring(ind + 1);
                    }
                    
                    if(a.startsWith(PREFIX_CHOICE)) {
                        a = a.substring(PREFIX_CHOICE.length(), a.lastIndexOf(POSTFIX_CHOICE));
                        a = LIBRARY_NAME + "." + hashTitle(a);
                        call.add(a);
                    } else if(a.startsWith("\"")) {
                        a = a.substring(1, a.lastIndexOf("\""));
                        System.out.println("String reference " + a);
                        
                        // create string reference
                        String refName = title + "_ref_s" + argStringCount++;
                        
                        outgoingReferences.put(refName, mainCode.size());
                        outgoingReferenceWidths.put(refName, 4);
                        
                        // write string data
                        byte[] bytes = a.getBytes();
                        
                        byte b1 = (byte)(bytes.length & 0xFF),
                             b2 = (byte)((bytes.length >> 8) & 0xFF);
                        
                        mainCode.add(b1);
                        mainCode.add(b2);
                        
                        for(int j = 0; j < bytes.length; j++) {
                            mainCode.add(bytes[j]);
                        }
                        
                        call.add(LIBRARY_NAME + "." + refName);
                    } else {
                        call.add(a);
                    }
                }
                
                functionCalls.add(call);
                nodeHasCommands = true;
            } else if(ln.startsWith(MARKER_END)) {
                nodeHasCommands = true;
            } else if(ln.startsWith(PREFIX_COMMENT)) {
                // skip
            } else if(!nodeHasCommands) {
                // description
                description += ln + "\n";
            }
        }
        
        // write final description
        outgoingReferences.put(title + "_ref_d", mainCode.size());
        outgoingReferenceWidths.put(title + "_ref_d", 4);
        
        //if(description.endsWith("\n")) description = description.substring(0, description.length() - 1);
        
        byte[] bytes = description.getBytes();
        for(int j = 0; j < bytes.length; j++) {
            mainCode.add(bytes[j]);
        }
        
        // write final header
        writeHeader(headerCode, title + "_ref_d", bytes.length, choiceTextReferences, choiceLengths, choiceTitleReferences, functionCalls, incomingReferences, incomingReferenceWidths);
        
        // correct code area references
        for(String k : outgoingReferences.keySet()) {
            if(k.matches(".+((_ref_d)|(_ref_c[0-9]+)|(_ref_s[0-9]+))")) {
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
    private static void writeHeader(List<Byte> code, String descriptionReference, int descriptionLength, List<String> choiceTextReferences, Map<String, Integer> choiceLengths, List<String> choiceTitleReferences, List<List<String>> functionCalls, HashMap<String, List<Integer>> incomingReferences, HashMap<String, Integer> incomingReferenceWidths) {
        // description length
        int len = descriptionLength;
        code.add((byte)(len & 0xFF));
        code.add((byte)((len >> 8) & 0xFF));
        
        // description reference
        addIncomingReference(incomingReferences, incomingReferenceWidths, descriptionReference, code.size(), true);
        
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
            addIncomingReference(incomingReferences, incomingReferenceWidths, textRef, code.size(), true);
            
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            
            // choice reference
            addIncomingReference(incomingReferences, incomingReferenceWidths, titleRef, code.size(), true);
            
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
        }
        
        // number of function calls
        code.add((byte) functionCalls.size());
        
        // calls
        for(int i = 0; i < functionCalls.size(); i++) {
            List<String> call = functionCalls.get(i);
            
            // function address
            addIncomingReference(incomingReferences, incomingReferenceWidths, call.get(0), code.size(), false);
            
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            code.add((byte) 0);
            
            // arguments
            int x = call.size() - 1;
            code.add((byte) x);
            
            for(int j = x; j > 0; j--) {
                addIncomingReference(incomingReferences, incomingReferenceWidths, call.get(j), code.size(), false);
                
                code.add((byte) 0);
                code.add((byte) 0);
                code.add((byte) 0);
                code.add((byte) 0);
            }
        }
    }
    
    /**
     * Adds an incoming reference
     * 
     * @param incomingReferences
     * @param ref
     * @param addr
     */
    private static void addIncomingReference(HashMap<String, List<Integer>> incomingReferences, HashMap<String, Integer> incomingReferenceWidths, String ref, int addr, boolean internal) {
        if(internal) ref = LIBRARY_NAME + "." + ref;
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
