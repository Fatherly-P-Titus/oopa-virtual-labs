# Robot Arm (Engineering lab)

`labs/engineering/robot_arm/` – planar two-link arm: forward kinematics, inverse kinematics and workspace.

## Model
- Links of lengths \(L_1\), \(L_2\); joint angles \(\theta_1\) (shoulder), \(\theta_2\) (elbow), measured from the previous link (standard planar RR).
- Forward kinematics:
  \[
  x = L_1\cos\theta_1 + L_2\cos(\theta_1+\theta_2),\quad
  y = L_1\sin\theta_1 + L_2\sin(\theta_1+\theta_2)
  \]
- Inverse kinematics (elbow-up / elbow-down):
  \[
  \cos\theta_2 = \frac{x^2+y^2-L_1^2-L_2^2}{2L_1L_2},\quad
  \theta_1 = \operatorname{atan2}(y,x) - \operatorname{atan2}(L_2\sin\theta_2,\, L_1+L_2\cos\theta_2)
  \]
- Reachable workspace: annulus between \(|L_1-L_2|\) and \(L_1+L_2\).

## Limits
- Planar, two revolute joints only. No dynamics, gravity, or joint limits enforced beyond a soft visual range.
- Point end-effector; no orientation DOF.
- IK fails gracefully outside the workspace.

## Files
- `scripts/robot-arm-model.js` – FK / IK (`window.RobotArmModel`).
- `scripts/robot-arm.js` – canvas + controls.
- `styles/robot-arm.css` – layout.
