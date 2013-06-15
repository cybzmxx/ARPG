package modules.gamescene
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	import animation.Animation;
	import animation.AnimationEvent;
	import animation.ISceneItem;
	import animation.animal.Player;
	import animation.animationtypes.EffectsAnimation;
	import animation.configs.ActionType;
	import animation.configs.Direction;

	import modules.ModulesManager;
	import modules.findpath.FindpathEvent;
	import modules.findpath.MapTileModel;
	import modules.moveaction.MoveActionEvent;

	import protobuf.E_ATTACK_TYPE;

	/**
	 * 操作真实地图
	 * @author 风之守望者 2012-7-1
	 */
	public class GameSceneManager extends ModulesManager
	{
		/** 场景地图配置 */
		private var sceneMapConfig:GameSceneConfig;

		/** 地图层 */
		private var gameSceneBackground:GameSceneBackground;

		/** 路径层 */
		private var pathlayer:Shape;

		/** 场景物件层 */
		private var sceneItemLayer:Sprite;

		private var playerDic:Dictionary = new Dictionary();

		/** 场景上物件 */
		private var sceneItems:Array = [];

		private var animalList:Array = [];

		private var skillEffects:Array = [];

		/** 准备特效与技能特效对应表 */
		private var skillDic:Dictionary = new Dictionary();

		public function get hero():Player
		{
			return GlobalData.hero;
		}

		private function get sceneLayer():Sprite
		{
			return UIAllRefer.sceneLayer;
		}

		public function GameSceneManager()
		{
			dispatcher.addEventListener("config_load_completed", configLoadCompleted);
			dispatcher.addEventListener("map_show_completed", mapShowCompleted);

			//初始化地图
			gameSceneBackground = new GameSceneBackground();
			sceneLayer.addChildAt(gameSceneBackground, 0);

			pathlayer = new Shape();
			pathlayer.name = "pathlayer";
			sceneLayer.addChild(pathlayer);

			sceneItemLayer = new Sprite();
			sceneItemLayer.name = "sceneItemLayer";
			sceneLayer.addChild(sceneItemLayer);
			sceneItemLayer.mouseEnabled = false;

			if (GlobalData.isShowGird)
				drawGird();

			addListeners();
		}

		private function configLoadCompleted(event:Event):void
		{
			trace("地图配置加载完成");


		}

		private function mapShowCompleted(event:Event):void
		{
			trace("地图显示完成");
			dispatcher.removeEventListener("map_show_completed", mapShowCompleted);

			dispatcher.dispatchEvent(new GameSceneEvent(GameSceneEvent.SCENE_COMPLETED));
		}

		private function addListeners():void
		{
			dispatcher.addEventListener(GameSceneEvent.ADD_HERO, onAddHero);
			dispatcher.addEventListener(GameSceneEvent.ADD_PLAYER, onAddPlayer);
			dispatcher.addEventListener(GameSceneEvent.REMOVE_PLAYER, onRemovePlayer);
			dispatcher.addEventListener(GameSceneEvent.PLAYER_WALK, onPlayerWalk);
			dispatcher.addEventListener(GameSceneEvent.CAST_SKILL, onCastSkill);
			dispatcher.addEventListener(GameSceneEvent.GET_SKILL_TARGET, onGetSkillTarget);

		}

		private function onAddHero(event:GameSceneEvent):void
		{
			//加载地图配置
			sceneMapConfig = new GameSceneConfig(GlobalData.mapId);

			var animal:Player = new Player();
			animal.name = "hero" + GlobalData.roleId;
			animal.mapX = event.data.mapX;
			animal.mapY = event.data.mapY;
			animal.clothing = event.data.clothing;
			animal.playerId = GlobalData.roleId;
			GlobalData.hero = animal;
			hero.mouseEnabled = false;
			hero.mouseChildren = false;

			addPlayer(animal);

			sceneLayer.addEventListener(MouseEvent.CLICK, onSceneClick);

			UIAllRefer.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			trace("添加人物完成");
		}

		private function onEnterFrame(event:Event):void
		{
			if (GameSceneConfig.mapData == null)
				return;

			setHeroCenter();

			for each (var ani:Animation in skillEffects)
			{
				ani.animationController.enterFrame();
			}
		}

		private function onAddPlayer(event:GameSceneEvent):void
		{
			var animal:Player = new Player();
			animal.name = "player" + event.data.playerId;
			animal.clothing = event.data.clothing;
			animal.mapX = event.data.mapX;
			animal.mapY = event.data.mapY;
			animal.playerId = event.data.playerId;

			addPlayer(animal);
		}

		private function onRemovePlayer(event:GameSceneEvent):void
		{
			var animal:Player = playerDic[event.data.playerId];
			removePlayer(animal);
		}

		private function addPlayer(animal:Player):void
		{
			sceneItemLayer.addChild(animal);
			playerDic[animal.playerId] = animal;
			animalList.push(animal);
			sceneItems.push(animal);
		}

		private function removePlayer(animal:Player):void
		{
			if (animal && animal.parent)
			{
				animal.parent.removeChild(animal);
			}

			var index:int;
			index = animalList.indexOf(animal);
			if (index != -1)
			{
				animalList.splice(index, 1);
			}
			index = sceneItems.indexOf(animal);
			if (index != -1)
			{
				sceneItems.splice(index, 1);
			}
		}

		private function onPlayerWalk(event:GameSceneEvent):void
		{
			var animal:Player = playerDic[event.data.playerId];
			animal.destination = new Point(event.data.mapX, event.data.mapY);
		}

		private function onGetSkillTarget(event:GameSceneEvent):void
		{
			//获取地图坐标
			var mapPoint:Point = MapTileModel.girdCoordinate(sceneLayer.mouseX, sceneLayer.mouseY);
			event.data.mapX = mapPoint.x;
			event.data.mapY = mapPoint.y;

			//获取攻击目标编号
			var targetAnimals:Array = [];

			var stg:Stage = sceneItemLayer.stage;
			var p:Point = new Point(stg.mouseX, stg.mouseY);
			stg.areInaccessibleObjectsUnderPoint(p)

			var underObjects:Array = stg.getObjectsUnderPoint(p);
			for each (var child:DisplayObject in underObjects)
			{
				var chain:Array = new Array(child);
				var par:DisplayObjectContainer = child.parent;
				while (par)
				{
					chain.unshift(par);
					par = par.parent;
				}
				var len:uint = chain.length;
				for (var i:uint = 0; i < len; i++)
				{
					var obj:DisplayObject = chain[i];
					var animal:Player = obj as Player;
					if (animal)
					{
						if (animal.playerId != GlobalData.roleId)
						{
							if (targetAnimals.indexOf(animal.playerId) == -1)
								targetAnimals.push(animal.playerId);
						}
					}

				}
			}
			event.data.targetAnimals = targetAnimals;
		}

		private function onCastSkill(event:GameSceneEvent):void
		{
			var animal:Player = playerDic[event.data.playerId];

			var targetPoint:Point = new Point();
			switch (event.data.type)
			{
				case E_ATTACK_TYPE.POINT:
					targetPoint.x = event.data.mapX;
					targetPoint.y = event.data.mapY;
					break;
				case E_ATTACK_TYPE.PLALER:
					var targetPlayer:Player = playerDic[event.data.targetId];
					if (targetPlayer)
					{
						targetPoint.x = targetPlayer.mapX;
						targetPoint.y = targetPlayer.mapY;
					}
					break;

			}
			var animalDirPoint:Point = new Point(targetPoint.x - animal.mapX, targetPoint.y - animal.mapY);
			var animalDir:int = Direction.getDirection(animalDirPoint);

			animal.action = ActionType.CASTSKILL;
			animal.direction = animalDir;

			var sftxl:EffectsAnimation = new EffectsAnimation("sftxl");
			sftxl.name = "sftxl";
			animal.addChild(sftxl);
			sftxl.addEventListener(AnimationEvent.LOOPED, onSFTXLooped);

			skillDic[sftxl] = {skillName: "lds", data: event.data};
			addEffects(sftxl);
		}

		private function onSFTXLooped(event:Event):void
		{
			var ani:EffectsAnimation = event.currentTarget as EffectsAnimation;
			removeEffects(ani);

			var skill:Object = skillDic[ani];
			if (skill)
			{
				var floorPoint:Point = new Point();
				switch (skill.data.type)
				{
					case E_ATTACK_TYPE.POINT:
						floorPoint = MapTileModel.realCoordinate(skill.data.mapX, skill.data.mapY);
						break;
					case E_ATTACK_TYPE.PLALER:
						var targetPlayer:Player = playerDic[skill.data.targetId];
						if (targetPlayer)
						{
							floorPoint.x = targetPlayer.floorX;
							floorPoint.y = targetPlayer.floorY;
						}
						break;

				}

				var lds:EffectsAnimation = new EffectsAnimation(skill.skillName);
				lds.name = skill.skillName;
				lds.floorPoint = floorPoint;
				lds.addEventListener(AnimationEvent.LOOPED, onLooped);

				sceneItemLayer.addChild(lds);
				addEffects(lds);
				delete skillDic[ani];
			}
		}

		private function onLooped(event:Event):void
		{
			var ani:EffectsAnimation = event.currentTarget as EffectsAnimation;
			removeEffects(ani);
		}

		private function addEffects(effect:EffectsAnimation):void
		{
			skillEffects.push(effect);
			sceneItems.push(effect);
		}

		private function removeEffects(effect:EffectsAnimation):void
		{
			if (effect.parent)
				effect.parent.removeChild(effect);

			var index:int;
			index = skillEffects.indexOf(effect);
			if (index != -1)
				skillEffects.splice(index, 1);
			index = sceneItems.indexOf(effect);
			if (index != -1)
				sceneItems.splice(index, 1);
		}

		/**
		 * 点击场景
		 */
		private function onSceneClick(event:MouseEvent):void
		{
			if (event.target != sceneLayer)
				return;
			//计算玩家所在的格子坐标
			var startPoint:Point = MapTileModel.girdCoordinate(hero.x, hero.y);
			//计算点击位置的格子坐标
			var endPoint:Point = MapTileModel.girdCoordinate(event.localX, event.localY);
			//trace("起点", startPoint, "	终点", endPoint);

			var findpathEvent:FindpathEvent = new FindpathEvent(FindpathEvent.FIND_PATH, startPoint.x, startPoint.y, endPoint.x, endPoint.y);
			//抛出事件获取路径
			dispatcher.dispatchEvent(findpathEvent);
			var path:Array = findpathEvent.path;
			//trace("A*路径", path);

			if (path)
			{
//				drawPath(path);

				dispatcher.dispatchEvent(new MoveActionEvent(MoveActionEvent.HERO_START_MOVE, path));
			}
			else
			{
				trace("无法找到路径");
			}
		}

		/**
		 * 绘制路径
		 * @param path 路径数据
		 */
		private function drawPath(path:Array):void
		{
			pathlayer.graphics.clear();
			if (path == null)
				return;
			pathlayer.graphics.beginFill(0xff0000);
			for (var i:int = 0; i < path.length; i++)
			{
				var realPoint:Point = MapTileModel.realCoordinate(path[i][0], path[i][1]);
				pathlayer.graphics.drawCircle(realPoint.x, realPoint.y, GameSceneConfig.TILE_HEIGHT / 2);
			}
			pathlayer.graphics.endFill();
		}

		/**
		 * 绘制网格
		 */
		private function drawGird():void
		{
			var shape:Shape = new Shape();
			shape.name = "gridShap";
			sceneLayer.addChild(shape);

			var startx:Number = -GameSceneConfig.TILE_WIDTH / 2;
			var starty:Number = -GameSceneConfig.TILE_HEIGHT / 2;
			shape.graphics.lineStyle(2, 0x00ff00);
			while (startx < GameSceneConfig.mapWidth + GameSceneConfig.TILE_WIDTH / 2)
			{
				shape.graphics.moveTo(startx, -GameSceneConfig.TILE_HEIGHT / 2);
				shape.graphics.lineTo(startx, GameSceneConfig.mapHeight + GameSceneConfig.TILE_HEIGHT / 2);
				startx += GameSceneConfig.TILE_WIDTH;
			}
			while (starty < GameSceneConfig.mapHeight + GameSceneConfig.TILE_HEIGHT / 2)
			{
				shape.graphics.moveTo(-GameSceneConfig.TILE_WIDTH / 2, starty);
				shape.graphics.lineTo(GameSceneConfig.mapWidth + GameSceneConfig.TILE_WIDTH / 2, starty);
				starty += GameSceneConfig.TILE_HEIGHT;
			}
		}

		/**
		 * 设置英雄为中心(地图卷动)
		 */
		private function setHeroCenter():void
		{
			//移动场景
			sceneLayer.x = int(UIAllRefer.stage.stageWidth / 2 - hero.x);
			sceneLayer.y = int(UIAllRefer.stage.stageHeight / 2 - hero.y);

			//设置场景移动边界(避免看到黑边)
			if (sceneLayer.x > 0)
			{
				sceneLayer.x = 0;
			}
			if (sceneLayer.y > 0)
			{
				sceneLayer.y = 0;
			}
			if (sceneLayer.x < UIAllRefer.stage.stageWidth - GameSceneConfig.mapWidth)
			{
				sceneLayer.x = UIAllRefer.stage.stageWidth - GameSceneConfig.mapWidth;
			}
			if (sceneLayer.y < UIAllRefer.stage.stageHeight - GameSceneConfig.mapHeight)
			{
				sceneLayer.y = UIAllRefer.stage.stageHeight - GameSceneConfig.mapHeight;
			}
			var showArea:Rectangle = new Rectangle(-sceneLayer.x, -sceneLayer.y, UIAllRefer.stage.stageWidth, UIAllRefer.stage.stageHeight);
			gameSceneBackground.showMap(GlobalData.mapId, showArea);

			//深度排序
			depthSort();
			//透明检测
			checkTransparent();

		}

		private function depthSort():void
		{
			sceneItems.sortOn("floorY");

			for (var i:int = 0; i < sceneItems.length; i++)
			{
				var sceneItem:ISceneItem = sceneItems[i];
				var animal:DisplayObject = sceneItem as DisplayObject;
				animal.parent.addChild(animal);
			}
		}

		private function checkTransparent():void
		{
			var mapData:Array = GameSceneConfig.mapData;
			for (var i:int = 0; i < animalList.length; i++)
			{
				var animal:Player = animalList[i];

				if (mapData[animal.mapX][animal.mapY] == MapTileModel.PATH_TRANSPARENT)
				{
					animal.alpha = 0.6;
				}
				else
				{
					animal.alpha = 1.0;
				}
			}

		}
	}
}