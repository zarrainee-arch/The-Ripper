# THE RIPPER — CONTRACT

## 1. Game Overview

**The Ripper** is a top-down AI pathfinding game inspired by Victorian-era Whitechapel.

The player must reach the Safe House before the Jack the Ripper-inspired NPC catches the player.

The main focus of the game is the implementation and comparison of Uniform Cost Search (UCS) and A* pathfinding.

---

## 2. AI Objective

The NPC uses pathfinding to search for the current position of the player.

For every search:

- Start node = Jack's current position
- Goal node = Player's current position

The NPC must find a valid path while avoiding obstacles.

---

## 3. Grid Configuration

| Property | Value |
|---|---|
| Grid Width | 20 cells |
| Grid Height | 12 cells |
| Cell Size | 40 × 40 pixels |
| Movement | 4-directional |
| Diagonal Movement | Not allowed |

The grid uses integer cell coordinates:

`Vector2i(x, y)`

Example:

```text
(0,0) (1,0) (2,0) (3,0)
(0,1) (1,1) (2,1) (3,1)
(0,2) (1,2) (2,2) (3,2)
````

---

## 4. Graph Representation

Each walkable grid cell represents a node in the graph.

A node can have up to four neighbors:

* Up
* Down
* Left
* Right

A cell is not considered a neighbor if:

* It is outside the grid.
* It is an obstacle.

The graph is implemented through `grid.gd`.

Important functions:

```gdscript
is_inside_grid()
is_walkable()
get_neighbors()
cell_to_world()
world_to_cell()
```

---

## 5. Obstacles

Obstacles represent blocked areas in the map.

Examples:

* Houses
* Closed roads
* Fences
* Blocked alleys
* Other environmental objects

Obstacle cells are not walkable and cannot be included in a path.

---

## 6. Movement Cost

Each normal movement between adjacent walkable cells has:

```text
Cost = 1
```

Therefore:

```text
Up    = 1
Down  = 1
Left  = 1
Right = 1
```

Diagonal movement is not allowed.

---

## 7. Uniform Cost Search (UCS)

UCS is implemented in:

`scripts/ucs.gd`

UCS evaluates nodes based on accumulated path cost:

```text
f(n) = g(n)
```

Where:

* `g(n)` = total cost from the start node to node `n`

UCS always expands the node with the smallest accumulated cost.

UCS must record:

* Expanded nodes
* Parent of each node
* Path cost
* Final path

---

## 8. A* Search

A* is implemented in:

`scripts/astar.gd`

A* evaluates nodes using:

```text
f(n) = g(n) + h(n)
```

Where:

* `g(n)` = actual cost from the start node to node `n`
* `h(n)` = estimated cost from node `n` to the goal
* `f(n)` = total estimated cost

A* must record:

* Expanded nodes
* Parent of each node
* Path cost
* Final path

---

## 9. Heuristics

Heuristics are implemented in:

`scripts/heuristic.gd`

### Manhattan Distance

The primary heuristic is:

```text
h(n) = |x1 - x2| + |y1 - y2|
```

Manhattan distance is appropriate because the game uses 4-directional movement without diagonal movement.

### Euclidean Distance

Euclidean distance may also be implemented for comparison:

```text
h(n) = sqrt((x1-x2)^2 + (y1-y2)^2)
```

---

## 10. Path Reconstruction

Both UCS and A* must store a parent for each explored node.

After reaching the goal:

```text
Goal
 ↓
Parent
 ↓
Parent
 ↓
Start
```

The path is reconstructed from the goal back to the start, then reversed so that the final path is:

```text
Start → ... → Goal
```

---

## 11. NPC Integration

The NPC uses the path returned by the selected search algorithm.

General flow:

```text
Jack position
      ↓
Start node
      ↓
Pathfinding algorithm
      ↓
Player position
      ↓
Goal node
      ↓
Final path
      ↓
NPC follows path
```

The NPC must not move through obstacle cells.

---

## 12. Re-planning

Because the player can move during the chase, the NPC may need to calculate a new path.

When re-planning occurs:

```text
New Jack position
        +
Current Player position
        ↓
   Search again
        ↓
    New path
```

The implementation should avoid recalculating the path unnecessarily every frame.

---

## 13. Search Visualization

The game should visualize the search process.

Visualization may include:

* Start node
* Goal node
* Expanded nodes
* Final path
* Obstacles

Suggested representation:

```text
Blue   = Player
Orange = Jack
Red    = Obstacle
Yellow = Expanded Node
Green  = Final Path
```

The visualization is implemented primarily in:

`scripts/visualization.gd`

---

## 14. AI Statistics

The game should display or record:

* Algorithm
* Heuristic
* Expanded Nodes
* Path Cost

Search time may also be recorded if required.

Example:

```text
Algorithm: A*
Heuristic: Manhattan
Expanded Nodes: 35
Path Cost: 18
```

---

## 15. AI Experiments

The main comparison will be:

### Experiment 1

```text
UCS
```

### Experiment 2

```text
A* + Manhattan
```

### Experiment 3

```text
A* + Euclidean
```

The team will compare:

* Number of expanded nodes
* Path cost
* Search time (if implemented)

The same map, start position, goal position, and movement rules should be used when comparing algorithms.

---

## 16. Day/Night Gameplay

The game may contain a Day/Night system.

### Day

* Player can explore the map.
* Jack is inactive/resting.

### Night

* Jack becomes active.
* Pathfinding is activated.
* Jack searches for and chases the player.

The Day/Night system is secondary to the AI pathfinding system.

If development time is limited, the AI core takes priority over the Day/Night system.

---

## 17. Win and Lose Conditions

### Player Wins

The player reaches the Safe House.

```text
Player → Safe House → WIN
```

### Player Loses

Jack catches the player.

```text
Jack → Player → GAME OVER
```

---

## 18. Team Development Rules

Each team member works primarily on their assigned files.

### Person 1 — Graph + UCS + NPC Integration

Main files:

```text
scripts/grid.gd
scripts/ucs.gd
scripts/npc.gd
scripts/player.gd
```

Responsibilities:

* Graph representation
* UCS
* Path reconstruction for UCS
* NPC path following
* Player movement
* AI integration

### Person 2 — A*

Main file:

```text
scripts/astar.gd
```

Responsibilities:

* A* implementation
* `g(n)`
* `h(n)`
* `f(n)`
* Path reconstruction
* Expanded node tracking

### Person 3 — Heuristic + Visualization + Evaluation

Main files:

```text
scripts/heuristic.gd
scripts/visualization.gd
```

Responsibilities:

* Manhattan heuristic
* Euclidean heuristic
* Search visualization
* AI statistics
* Experiment and comparison

---

## 19. Important Development Rules

* Do not modify another person's core algorithm without discussing the change with the responsible team member.
* Shared interfaces and data structures should be discussed before major changes.
* Avoid simultaneous changes to `main.tscn` whenever possible to reduce Git merge conflicts.
* Each member should test their changes locally before pushing.
* Do not push directly to `main` during feature development.
* Use a separate branch for each person's work.

---

## 20. Development Priority

The development priority is:

1. Grid / Graph
2. UCS
3. A*
4. Heuristic
5. NPC integration
6. Search visualization
7. AI statistics
8. Win / Lose system
9. Day / Night system
10. Additional atmosphere and visual features

The AI pathfinding system is the primary focus of the project.

```