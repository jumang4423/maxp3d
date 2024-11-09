// max patch to 3D written in Processing Java.
// Basics:
// 1. Parse Max patch
// 2. Display patch functions in 3D
// 3. Display patch connections in 3D (curved lines)
// 4. Add light and camera
// 5. Rotate x only with slow speed.
// 6. Center camera based on the mean position of all nodes
// 7. Render nodes as squares with text
// 8. Apply fixed sag to connections to simulate a drooping effect

import processing.core.*;
import processing.data.*;
import java.util.*;

String maxp_loc = "./test.maxpat";

ArrayList<Node> nodes;
ArrayList<Connection> connections;

PVector meanPosition = new PVector(0, 0, 0);

float angle = 0;

PFont font;

void setup() {
    size(1280, 720, P3D);
    background(255);
    parseMaxPatch(maxp_loc);
    calculateMeanPosition();
    font = createFont("Iosevka Term", 16);
}

void draw() {
    background(255);
    
    float camDistance = 500;
    camera(meanPosition.x, meanPosition.y, meanPosition.z + camDistance, 
           meanPosition.x, meanPosition.y, meanPosition.z, 
           0, 1, 0);
    
    translate(meanPosition.x, meanPosition.y, meanPosition.z);
    rotateY(angle);
    angle += 0.02;
    
    for (Connection conn : connections) {
        conn.display();
    }

    for (Node node : nodes) {
        node.display();
    }
}

void parseMaxPatch(String filepath) {
    JSONObject patch = loadJSONObject(filepath);
    JSONObject patcher = patch.getJSONObject("patcher");
    JSONArray boxes = patcher.getJSONArray("boxes");
    JSONArray lines = patcher.getJSONArray("lines");

    nodes = new ArrayList<Node>();
    connections = new ArrayList<Connection>();

    for (int i = 0; i < boxes.size(); i++) {
        JSONObject boxObject = boxes.getJSONObject(i).getJSONObject("box");
        String id = boxObject.getString("id");
        String maxClass = boxObject.getString("maxclass");
        String text;
        
        if (maxClass.equals("flonum")) {
            text = "flonum";
        } else if (maxClass.equals("toggle")) {
            text = "×";
        } else if (maxClass.equals("button")) {
            text = "o";
        } else if (maxClass.equals("slider")) {
            text = "00000";
        } else if (maxClass.equals("live.dial")) {
            text = "0%";
        } else {
            text = boxObject.hasKey("text") ? boxObject.getString("text") : "???";
        }
        
        JSONArray rect = boxObject.getJSONArray("patching_rect");
        float x = rect.getFloat(0);
        float y = rect.getFloat(1);
        float z = rect.getFloat(2);
        nodes.add(new Node(id, text, maxClass, x, y, z));
    }

    for (int i = 0; i < lines.size(); i++) {
        JSONObject lineObject = lines.getJSONObject(i).getJSONObject("patchline");
        JSONArray source = lineObject.getJSONArray("source");
        JSONArray destination = lineObject.getJSONArray("destination");
        String sourceId = source.getString(0);
        String destId = destination.getString(0);
        connections.add(new Connection(sourceId, destId));
    }
}

void calculateMeanPosition() {
    if (nodes.size() == 0) return;
    
    float sumX = 0;
    float sumY = 0;
    float sumZ = 0;
    
    for (Node node : nodes) {
        sumX += node.position.x;
        sumY += node.position.y;
        sumZ += node.position.z;
    }
    
    meanPosition.x = sumX / nodes.size();
    meanPosition.y = sumY / nodes.size();
    meanPosition.z = sumZ / nodes.size();
}

class Node {
    String id;
    String label;
    String maxClass;
    PVector position;
    float width = 50;
    float height = 30;
    float depth = 5;
    boolean isBlinking = false;
    String originalLabel;
    int sliderLength = 5;
    
    Node(String id, String label, String maxClass, float x, float y, float z) {
        this.id = id;
        this.label = label;
        this.originalLabel = label;
        this.maxClass = maxClass;
        this.position = new PVector(x, y, z);
        
        if (maxClass.equals("button")) {
            isBlinking = true;
        }
    }
    void display() {
        pushMatrix();
        translate(position.x - meanPosition.x, position.y - meanPosition.y, position.z - meanPosition.z);
        
        rotateY(-angle);
        
        noStroke();
        
        textFont(font);
        float textWidthValue = textWidth(label.toUpperCase()) + 10;
        
        float sectionHeight = height/3;
        
        pushMatrix();
        translate(0, -sectionHeight*1.25, 0);
        fill(200);
        box(textWidthValue, sectionHeight*0.5, depth);
        popMatrix();
        
        fill(255);
        box(textWidthValue, sectionHeight*2, depth);
        
        pushMatrix();
        translate(0, sectionHeight*1.25, 0);
        fill(200);
        box(textWidthValue, sectionHeight*0.5, depth);
        popMatrix();
        
        fill(128);
        textAlign(CENTER, CENTER);
        
        String displayText = label.toUpperCase();
        if (maxClass.equals("flonum")) {
            float randomNumber = random(0, 100);
            displayText = String.format("▶ %.2f", randomNumber);
        } else if (maxClass.equals("button")) {
            displayText = (frameCount % 2 == 0) ? "O" : "X";
        } else if (maxClass.equals("slider")) {
            displayText = generateSliderText();
        } else if (maxClass.equals("live.dial")) {
            int percentage = int(random(0, 101));  // 0 to 100
            displayText = percentage + "%";
        }
        
        pushMatrix();
        translate(0, -2, depth/2 + 1);
        text(displayText, 0, 0);
        popMatrix();
        popMatrix();
    }
    
    String generateSliderText() {
        char[] text = new char[sliderLength];
        int randomPosition = int(random(sliderLength));
        
        // Fill with zeros first
        for (int i = 0; i < sliderLength; i++) {
            text[i] = '0';
        }
        
        // Randomly replace some positions with 'x'
        for (int i = randomPosition; i < sliderLength; i++) {
            text[i] = 'x';
        }
        
        return new String(text);
    }
}

class Connection {
    String fromId;
    String toId;
    PVector fromPos;
    PVector toPos;
    PVector control;
    
    Connection(String fromId, String toId) {
        this.fromId = fromId;
        this.toId = toId;
        this.fromPos = getNodePosition(fromId);
        this.toPos = getNodePosition(toId);
        this.control = getFixedControlPoint();
    }
    
    PVector getNodePosition(String id) {
        for (Node node : nodes) {
            if (node.id.equals(id)) {
                return node.position.copy();
            }
        }
        return new PVector(0, 0, 0);
    }
    
    PVector getFixedControlPoint() {
        PVector mid = PVector.add(fromPos, toPos).div(2);
        mid.y += 50;
        return mid;
    }
    
    void display() {
        stroke(200);
        strokeWeight(4);
        noFill();
        beginShape();
        curveVertex(fromPos.x - meanPosition.x, fromPos.y - meanPosition.y, fromPos.z - meanPosition.z);
        curveVertex(fromPos.x - meanPosition.x, fromPos.y - meanPosition.y, fromPos.z - meanPosition.z);
        curveVertex(control.x - meanPosition.x, control.y - meanPosition.y, control.z - meanPosition.z);
        curveVertex(toPos.x - meanPosition.x, toPos.y - meanPosition.y, toPos.z - meanPosition.z);
        curveVertex(toPos.x - meanPosition.x, toPos.y - meanPosition.y, toPos.z - meanPosition.z);
        endShape();
    }
}
