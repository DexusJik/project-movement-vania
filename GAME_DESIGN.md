# Game Design Document: MovementVania

## 1. Core Vision
MovementVania is a kinematic-driven platformer focusing on fluid, weighted movement and shape-shifting (morphing) to navigate the environment and engage in combat. The goal is to provide a "snappy" yet physics-aware feel where momentum and state transitions are key to mastery.

## 2. Technical Specifications

### Scale & Units
- **Unit Standard**: 1 Meter = 100 Units.
- **Coordinate System**: Matter.js (X-right, Y-down).

### Object Dimensions
| Object | State | Width | Height | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Player** | Standing | 40 | 180 | Base state |
| **Player** | Crouch | 40 | 90 | Low profile, moderate slope slide |
| **Player** | Superman | 180 | 40 | Horizontal glide state |
| **Player** | Ball | 60 | 60 | Compact state, maximum slope slide |
| **Crate** | Default | 100 | 100 | Standard environment object |

### World Layout
- **Room Dimensions**: 3000w $\times$ 1000h.
- **Boundaries**: Static walls on all four sides to contain the simulation.
- **Camera**: Follows player with clamping to room edges.

## 3. Mechanics Breakdown

### Locomotion
- **Kinematic Movement**: Velocity is handled via lerping towards a target velocity based on input.
- **Surface-Based Accel**: Different acceleration values for ground and air to provide distinct feel.
- **Rotation Lock**: Player is strictly prohibited from rotating (`setAngle(0)` every frame) to prevent toppling.

### Morphing System
- **Trigger**: Controlled by the Sticks.
    - **LS Down**: Transition to Crouch.
    - **RS Up**: Transition to Superman.
    - **RS Down**: Transition to Ball.
    - **Neutral**: Return to Normal.
- **Ground Pinning**: During morphs, the body center is shifted to keep the bottom edge pinned to the ground, preventing clipping or "popping."
- **Safety Check**: Superman morph is blocked if the 180-unit width expansion would overlap with non-static objects.
- **Slope Dynamics**:
    - `Normal`: Base slope friction.
    - `Crouch`: Reduced friction, moderate slide force.
    - `Ball`: Minimal friction, maximum slide force (projectile-like).
    - `Superman`: High friction, minimal slide force (punishing drag).
    - **Slope Alignment**: In Superman state, the character's visual/collision orientation should align with the slope angle for a natural look. This must be handled as a visual/temporary rotation that resets instantly upon exiting the state to maintain the strict Rotation Lock.

### Gliding Physics (Superman State)
- **Glide Gravity**: significantly lower than standard gravity.
- **Dynamic Lift**: The effective gravity is reduced further as horizontal velocity increases:
  `ActualGravity = GlideGravity - (HorizontalSpeed * LiftFactor)`
- **Glide Locomotion**: Higher max speed and acceleration than standing state to emphasize momentum.

## 4. State Machine

### Morph States
- `normal`: Base state (40x180).
- `superman`: Horizontal gliding (180x40).
- `ball`: Compact physics state (60x60).

### Combat States
- `idle`: No active combat action.
- `vaulting`: Passive state during Superman morph.
- `slamming`: Active descent during Ball morph.
- `dashing`: High-velocity horizontal burst.
- `attacking`: Active attack frame.

## 5. Roadmap
- [ ] **Enemy AI**: Simple patrol and reaction behaviors.
- [ ] **Level Design**: Integration of platforms, slopes, and hazards.
- [ ] **Advanced Combos**: Expanding the `attackPressedRT` logic into a full combo system.
- [ ] **Visual Feedback**: Adding animations or color changes based on state.
