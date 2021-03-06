import 'dart:async';

import 'package:bonfire/bonfire.dart';
import 'package:darkness_dungeon/enemies/imp.dart';
import 'package:darkness_dungeon/enemies/mini_boss.dart';
import 'package:darkness_dungeon/main.dart';
import 'package:darkness_dungeon/util/localization/strings_location.dart';
import 'package:darkness_dungeon/util/sounds.dart';
import 'package:flame/animation.dart' as FlameAnimation;
import 'package:flame/position.dart';
import 'package:flame/text_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class Boss extends SimpleEnemy {
  final Position initPosition;
  double attack = 40;

  bool addChild = false;
  bool firstSeePlayer = false;

  List<Enemy> children = List();

  Boss(this.initPosition)
      : super(
          animIdleRight: FlameAnimation.Animation.sequenced(
            "enemy/boss/boss_idle.png",
            4,
            textureWidth: 32,
            textureHeight: 36,
          ),
          animIdleLeft: FlameAnimation.Animation.sequenced(
            "enemy/boss/boss_idle_left.png",
            4,
            textureWidth: 32,
            textureHeight: 36,
          ),
          animRunRight: FlameAnimation.Animation.sequenced(
            "enemy/boss/boss_run_right.png",
            4,
            textureWidth: 32,
            textureHeight: 36,
          ),
          animRunLeft: FlameAnimation.Animation.sequenced(
            "enemy/boss/boss_run_left.png",
            4,
            textureWidth: 32,
            textureHeight: 36,
          ),
          initPosition: initPosition,
          width: tileSize * 1.5,
          height: tileSize * 1.7,
          speed: tileSize / 0.35,
          life: 200,
          collision: Collision(
              width: tileSize * 0.9,
              height: tileSize * 0.9,
              align: Offset(tileSize * 0.3, tileSize * 0.8)),
        );

  @override
  void render(Canvas canvas) {
    this.drawDefaultLifeBar(canvas);
    drawBarSummonEnemy(canvas);

    super.render(canvas);
  }

  @override
  void update(double dt) {
    this.timers['addChild']?.update(dt);
    if (!firstSeePlayer) {
      this.seePlayer(
        observed: (p) {
          firstSeePlayer = true;
          gameRef.gameCamera.moveToPositionAnimated(
            Position(
              this.position.center.dx,
              this.position.center.dy,
            ),
            zoom: 2,
            finish: () {
              _showConversation();
            },
          );
        },
        radiusVision: tileSize * 7,
      );
    }
    this.seePlayer(
      observed: (player) {
        if (children.isEmpty ||
            children.where((e) => !e.isDead).length == 0 &&
                children.length < 3) {
          addChildInMap();
        }
      },
      radiusVision: tileSize * 3,
    );

    if (life < 150 && children.length == 0) {
      addChildInMap();
    }

    if (life < 100 && children.length == 1) {
      addChildInMap();
    }

    if (life < 50 && children.length == 2) {
      addChildInMap();
    }

    this.seeAndMoveToPlayer(
      closePlayer: (player) {
        execAttack();
      },
      radiusVision: tileSize * 3,
    );

    super.update(dt);
  }

  @override
  void die() {
    gameRef.add(
      AnimatedObjectOnce(
        animation: FlameAnimation.Animation.sequenced(
          "explosion.png",
          7,
          textureWidth: 32,
          textureHeight: 32,
        ),
        position: this.position,
      ),
    );
    children.forEach((e) {
      if (!e.isDead) e.die();
    });
    remove();
    super.die();
  }

  void addChildInMap() {
    if (this.timers['addChild'] == null) {
      this.timers['addChild'] = IntervalTick(5000);
    }

    if (!this.timers['addChild'].update(dtUpdate)) return;

    Rect positionExplosion;

    switch (this.directionThatPlayerIs()) {
      case Direction.left:
        positionExplosion = this.position.translate(width * -2, 0);
        break;
      case Direction.right:
        positionExplosion = this.position.translate(width * 2, 0);
        break;
      case Direction.top:
        positionExplosion = this.position.translate(0, height * -2);
        break;
      case Direction.bottom:
        positionExplosion = this.position.translate(0, height * 2);
        break;
    }

    Enemy e = children.length == 2
        ? MiniBoss(
            Position(
              positionExplosion.left,
              positionExplosion.top,
            ),
          )
        : Imp(
            Position(
              positionExplosion.left,
              positionExplosion.top,
            ),
          );

    gameRef.add(
      AnimatedObjectOnce(
        animation: FlameAnimation.Animation.sequenced(
          "smoke_explosin.png",
          6,
          textureWidth: 16,
          textureHeight: 16,
        ),
        position: positionExplosion,
      ),
    );

    children.add(e);
    gameRef.addGameComponent(e);
  }

  void execAttack() {
    this.simpleAttackMelee(
        heightArea: tileSize * 0.62,
        widthArea: tileSize * 0.62,
        damage: attack,
        interval: 1500,
        attackEffectBottomAnim: FlameAnimation.Animation.sequenced(
          'enemy/atack_effect_bottom.png',
          6,
          textureWidth: 16,
          textureHeight: 16,
        ),
        attackEffectLeftAnim: FlameAnimation.Animation.sequenced(
          'enemy/atack_effect_left.png',
          6,
          textureWidth: 16,
          textureHeight: 16,
        ),
        attackEffectRightAnim: FlameAnimation.Animation.sequenced(
          'enemy/atack_effect_right.png',
          6,
          textureWidth: 16,
          textureHeight: 16,
        ),
        attackEffectTopAnim: FlameAnimation.Animation.sequenced(
          'enemy/atack_effect_top.png',
          6,
          textureWidth: 16,
          textureHeight: 16,
        ),
        execute: () {
          Sounds.attackEnemyMelee();
        });
  }

  @override
  void receiveDamage(double damage, int id) {
    this.showDamage(
      damage,
      config: TextConfig(
        fontSize: 10,
        color: Colors.white,
        fontFamily: 'Normal',
      ),
    );
    super.receiveDamage(damage, id);
  }

  void drawBarSummonEnemy(Canvas canvas) {
    if (position == null) return;
    double yPosition = position.top;
    double widthBar = (width - 10) / 3;
    if (children.length < 1)
      canvas.drawLine(
          Offset(position.left, yPosition),
          Offset(position.left + widthBar, yPosition),
          Paint()
            ..color = Colors.orange
            ..strokeWidth = 1
            ..style = PaintingStyle.fill);

    double lastX = position.left + widthBar + 5;
    if (children.length < 2)
      canvas.drawLine(
          Offset(lastX, yPosition),
          Offset(lastX + widthBar, yPosition),
          Paint()
            ..color = Colors.orange
            ..strokeWidth = 1
            ..style = PaintingStyle.fill);

    lastX = lastX + widthBar + 5;
    if (children.length < 3)
      canvas.drawLine(
          Offset(lastX, yPosition),
          Offset(lastX + widthBar, yPosition),
          Paint()
            ..color = Colors.orange
            ..strokeWidth = 1
            ..style = PaintingStyle.fill);
  }

  void _showConversation() {
    Sounds.interaction();
    TalkDialog.show(gameRef.context, [
      Say(
        getString('talk_kid_1'),
        Flame.util.animationAsWidget(
          Position(80, 100),
          FlameAnimation.Animation.sequenced(
            "npc/kid_idle_left.png",
            4,
            textureWidth: 16,
            textureHeight: 22,
          ),
        ),
        personDirection: PersonDirection.RIGHT,
      ),
      Say(
        getString('talk_boss_1'),
        Flame.util.animationAsWidget(
          Position(80, 100),
          FlameAnimation.Animation.sequenced(
            "enemy/boss/boss_idle.png",
            4,
            textureWidth: 32,
            textureHeight: 36,
          ),
        ),
        personDirection: PersonDirection.LEFT,
      ),
      Say(
        getString('talk_player_3'),
        Flame.util.animationAsWidget(
          Position(80, 100),
          FlameAnimation.Animation.sequenced(
            "player/knight_idle.png",
            4,
            textureWidth: 16,
            textureHeight: 22,
          ),
        ),
        personDirection: PersonDirection.LEFT,
      ),
      Say(
        getString('talk_boss_2'),
        Flame.util.animationAsWidget(
          Position(80, 100),
          FlameAnimation.Animation.sequenced(
            "enemy/boss/boss_idle.png",
            4,
            textureWidth: 32,
            textureHeight: 36,
          ),
        ),
        personDirection: PersonDirection.RIGHT,
      ),
    ], finish: () {
      Sounds.interaction();
      addInitChild();
      Future.delayed(Duration(milliseconds: 500), () {
        gameRef.gameCamera.moveToPlayerAnimated();
        Sounds.playBackgroundBoosSound();
      });
    }, onChangeTalk: (index) {
      Sounds.interaction();
    });
  }

  void addInitChild() {
    addImp(position.left - tileSize, position.top - tileSize);
    addImp(position.left - tileSize, position.bottom + tileSize);
  }

  void addImp(double x, double y) {
    gameRef.add(
      AnimatedObjectOnce(
        animation: FlameAnimation.Animation.sequenced(
          "smoke_explosin.png",
          6,
          textureWidth: 16,
          textureHeight: 16,
        ),
        position: Rect.fromLTWH(x, y, 32, 32),
      ),
    );
    gameRef.addGameComponent(Imp(
      Position(
        x,
        y,
      ),
    ));
  }
}
