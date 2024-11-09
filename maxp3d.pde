// max patch to 3d visualization using processing java
// features:
// 1. parse max patch
// 2. display patch functions in 3d
// 3. display patch connections as curved lines
// 4. add lighting and camera
// 5. slow rotation around y-axis
// 6. center camera based on nodes' mean position
// 7. render nodes as boxes with text
// 8. apply fixed sag to connections for a drooping effect

import processing.core.*;
import processing.data.*;
import java.util.*;

final String MAX_PATCH_LOCATION = "./test.maxpat";
final int WINDOW_WIDTH = 1280;
final int WINDOW_HEIGHT = 720;
final float CAMERA_DISTANCE = 500;
final float ROTATION_SPEED = 0.02;
final String FONT_NAME = "Iosevka Term";
final int FONT_SIZE = 16;

ArrayList<Node> nodes;
ArrayList<Connection> connections;
PVector meanPosition = new PVector();
float angle = 0;
PFont font;

void settings() {
    size(WINDOW_WIDTH, WINDOW_HEIGHT, P3D);
}

void setup() {
    background(255);
    parseMaxPatch(MAX_PATCH_LOCATION);
    calculateMeanPosition();
    font = createFont(FONT_NAME, FONT_SIZE);
}

void draw() {
    background(255);
    setupCamera();
    applyTransformations();
    renderConnections();
    renderNodes();
}

void setupCamera() {
    camera(meanPosition.x, meanPosition.y, meanPosition.z + CAMERA_DISTANCE,
           meanPosition.x, meanPosition.y, meanPosition.z,
           0, 1, 0);
}

void applyTransformations() {
    translate(meanPosition.x, meanPosition.y, meanPosition.z);
    rotateY(angle);
    angle += ROTATION_SPEED;
}

void renderConnections() {
    for (Connection conn : connections) {
        conn.display();
    }
}

void renderNodes() {
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
        JSONObject box = boxes.getJSONObject(i).getJSONObject("box");
        String id = box.getString("id");
        String maxClass = box.getString("maxclass");
        String text = getNodeText(box, maxClass);
        
        JSONArray rect = box.getJSONArray("patching_rect");
        float x = rect.getFloat(0);
        float y = rect.getFloat(1);
        float z = rect.getFloat(2) *1.5;
        nodes.add(new Node(id, text, maxClass, x, y, z));
    }

    for (int i = 0; i < lines.size(); i++) {
        JSONObject line = lines.getJSONObject(i).getJSONObject("patchline");
        String sourceId = line.getJSONArray("source").getString(0);
        String destId = line.getJSONArray("destination").getString(0);
        connections.add(new Connection(sourceId, destId));
    }
}

String getNodeText(JSONObject box, String maxClass) {
    switch (maxClass) {
        case "flonum":
            return "flonum";
        case "toggle":
            return "×";
        case "button":
            return "o";
        case "slider":
            return "00000";
        case "live.dial":
            return "0%";
        default:
            return box.hasKey("text") ? box.getString("text") : "???";
    }
}

void calculateMeanPosition() {
    if (nodes.isEmpty()) return;
    
    PVector sum = new PVector();
    for (Node node : nodes) {
        sum.add(node.position);
    }
    meanPosition = PVector.div(sum, nodes.size());
}

class Node {
    String id;
    String label;
    String maxClass;
    PVector position;
    static final float WIDTH = 50;
    static final float HEIGHT = 30;
    static final float DEPTH = 5;
    boolean isBlinking;
    String originalLabel;
    int sliderLength = 5;

    Node(String id, String label, String maxClass, float x, float y, float z) {
        this.id = id;
        this.label = label;
        this.originalLabel = label;
        this.maxClass = maxClass;
        this.position = new PVector(x, y, z);
        this.isBlinking = maxClass.equals("button");
    }

    void display() {
        pushMatrix();
        translate(position.x - meanPosition.x, position.y - meanPosition.y, position.z - meanPosition.z);
        rotateY(-angle);
        noStroke();
        textFont(font);

        float textWidthValue = textWidth(label.toUpperCase()) + 10;
        float sectionHeight = HEIGHT / 3;

        // Top section
        pushMatrix();
        translate(0, -sectionHeight * 1.25, 0);
        fill(200);
        box(textWidthValue, sectionHeight * 0.5, DEPTH);
        popMatrix();

        // Middle section
        fill(255);
        box(textWidthValue, sectionHeight * 2, DEPTH);

        // Bottom section
        pushMatrix();
        translate(0, sectionHeight * 1.25, 0);
        fill(200);
        box(textWidthValue, sectionHeight * 0.5, DEPTH);
        popMatrix();

        // Display text
        fill(128);
        textAlign(CENTER, CENTER);
        String displayText = getDisplayText();
        
        pushMatrix();
        translate(0, -2, DEPTH / 2 + 1);
        text(displayText, 0, 0);
        popMatrix();
        popMatrix();
    }

    String getDisplayText() {
        switch (maxClass) {
            case "flonum":
                return String.format("▶ %.2f", random(0, 100));
            case "button":
                return (frameCount % 2 == 0) ? "O" : "X";
            case "slider":
                return generateSliderText();
            case "live.dial":
                return int(random(0, 101)) + "%";
            default:
                return label.toUpperCase();
        }
    }

    String generateSliderText() {
        char[] text = new char[sliderLength];
        int randomPosition = int(random(sliderLength));
        Arrays.fill(text, '0');
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
        this.control = calculateControlPoint();
    }

    PVector getNodePosition(String id) {
        for (Node node : nodes) {
            if (node.id.equals(id)) {
                return node.position.copy();
            }
        }
        return new PVector();
    }

    PVector calculateControlPoint() {
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
