import 'package:bonfire/bonfire.dart';

///
/// Created by
///
/// ─▄▀─▄▀
/// ──▀──▀
/// █▀▀▀▀▀█▄
/// █░░░░░█─█
/// ▀▄▄▄▄▄▀▀
///
/// Rafaelbarbosatec
/// on 23/12/21

/// This mixin give to the component the pushable behavior.
/// To use this mixin the Component must have a `Movement` mixin.
mixin Pushable on BlockMovementCollision {
  bool enablePushable = true;

  @override
  void onMovementCollision(GameComponent component, bool active) {
    if (enablePushable) {
      if (this is Movement) {
        if (!active && component is Movement) {
          if (!onPush(component)) {
            super.onMovementCollision(component, active);
          }
          Vector2 displacement = center - component.center;
          if (displacement.x.abs() > displacement.y.abs()) {
            if (displacement.x < 0) {
              (this as Movement).moveLeft((this as Movement).speed);
            } else {
              (this as Movement).moveRight((this as Movement).speed);
            }
          } else {
            if (displacement.y < 0) {
              (this as Movement).moveUp((this as Movement).speed);
            } else {
              (this as Movement).moveDown((this as Movement).speed);
            }
          }
        }
      } else {
        // ignore: avoid_print
        print(
            'The mixin Pushable not working in ($this) because this component don`t have the `Movement` mixin');
      }
    }
    return super.onMovementCollision(component, active);
  }

  /// Returning true if the component is pushable, false otherwise.
  bool onPush(GameComponent component) {
    return true;
  }
}
