from snippets.mass_edits import mass_translate

REPLACE_MAP = {
    "Continue...": "次へ…",
    "Do nothing.": "何もしない。",
    "Do something onboard the ship.": "船内で何かする。",
    "...": "...",
    "Nevermind.": "何でもない。",
    "An unvisited location.": "未訪問の地点",
    "Explored location. Nothing left of interest.": "訪問済みの地点。面白いものは残っていない。",
    "YOU SHOULD NEVER SEE THIS": "これを見てはいけない",
    "Use your blessing to avoid combat.": "祝福を使って戦闘を避ける。",
    "Decline.": "拒否する。",
    "Yes.": "はい。",
    "Refuse.": "断る。",
    "No.": "いいえ。",
    "You start calibrating the drone...": "ドローンの調整を開始します……",
    "You finish calibrating the drone successfully.": "ドローンの調整が成功しました。",
    "Return to the toggle menu.": "切り替えメニューに戻る。",
    "Renegade Cruiser": "レネゲイド巡洋艦",
    "Leave.": "離れる。",
    "Detach both modules.": "モジュールを両方取り外す。",
    "Exit hyperspeed.": "ハイパースピードを抜ける。",
    "You install the upgrade.": "アップグレードをインストールしています。",
    "You start the process.": "プロセスを開始します。",
    "You finish the process.": "プロセスが完了しました。",
    "Your crew cannot be cloned on your ship as they are inside the cannon.": "あなたのクルーは砲台の中にいるので、船内でクローンできません。",
    "You install the modification.": "改造をインストールしています。",
    "Are you sure? You will not be able to retrieve them without a Clone Bay, and all skills will be lost.": "よろしいですか？クローンベイがないとクルーに戻すことができない上に、すべてのスキルが失われます。",
    "Reset the cannon.": "砲台をリセットする。",
    "You reset the weapon.": "兵器をリセットしています。",
    "You finish resetting the weapon.": "兵器をリセットしました。",
    "Your Morph transforms into a new shape.": "あなたのモーフは新しい形に変身しています。",
    "Projectile": "発射物",
    "(Clone Bay) Revive your crew.": "(クローンベイ)クルーを復活させる。",
    "Though your crew's memories have been almost completely erased, they remember enough to at least remain loyal to the Federation.": "あなたのクルーの記憶はほぼ全て消去されましたが、少なくとも連邦への忠誠心は残っています。",
    "Ignore them.": "無視する。",
    "Are you sure you want to change the drone's settings?": "ドローンの設定を変えますがよろしいですか？",
    "Reroute.": "ルートを変更する。",
    "Accept their surrender.": "降伏を受け入れる。",
    "Nevermind, do something else.": "気にせず、他のことをする。",
    "Continue to the fight!": "戦闘を続ける！",
    "???": "???",
    "Sylvan": "シルヴァン",
    "YOU SHOULD NEVER SEE THIS.": "これを見てはいけない。",
    "No weapon has ever sparked a larger ethical controversy, but if it works it works.": "今までこれほど大きな倫理論争を引き起こした兵器は存在しないが、使えるなら問題はない。",
    "Accept.": "受け入れる。",
    "No thanks.": "大丈夫。",
    "Contact Federation command.": "連邦司令部に連絡する。",
    "Multiverse Renegade": "マルチバース・レネゲイド",
    "Attack!": "攻撃！",
    ".": ".",
    "Continue with the jump.": "ジャンプを続ける。",
    "You prepare to jump to the new co-ordinates, and change your flight path accordingly.": "飛行経路を変更し、新しい座標にジャンプする準備ができました。",
    "You prepare to secure their cargo by force.": "あなたは彼らの積荷を力ずくで確保しようとしています。",
    "Agree.": "同意する。",
    "Hail them.": "挨拶する。",
    "Avoid the ship.": "船を避ける。",
    "Your Morph transforms back to its original shape.": "あなたのモーフは元の形に戻っています。",
    "Go back.": "戻る。",
    "ESSENTIAL SYSTEMS": "主システム",
    "AUXILIARY SYSTEMS": "補助システム",
    "(Cloaking) Cloak and try to escape.": "(クローク)クロークして逃げる。",
    "(Adv. Engines) Try to escape the guard.": "(高度なエンジン)警備員から逃げる。",
    "Character Recruited": "キャラクター召集済み",
    "Explore.": "探索する。",
    "(Adv. Piloting) Activate the auto-pilot to try and escape.": "(高度なパイロット)自動操縦を起動して逃げる。",
    "Detach the modules.": "モジュールを取り外す。",
    "DECKHANDS": "搭乗員",
    "Before you shop, you still have some time to do something else aboard the ship.": "買い物をする前に、船内で何か他のことをする時間がまだあります。",
    "Success!": "成功！",
    "Loot Acquired": "獲得済み戦利品",
    "Modular Laser": "モジュラー・レーザー",
    "Mod. Laser": "Mod. レーザー",
    "Modular Ion": "モジュラー・イオン",
    "Mod. Ion": "Mod. イオン",
    "They stay outside your weapons range, and eventually jump away.": "彼らはあなたの射程範囲外に留まり、ついに飛び去ってしまった。",
    "DRONE": "ドローン",
    "*%$##@*%!": "*%$##@*%!",
    "Servant": "奴隷",
    "Demand the surrender of their goods.": "物品の引き渡しを要求する。",
    "WEAPONS OF THE DAY [33% OFF]": "今日の兵器 [33% OFF]",
    "They look like they don't want to fight. They are trying to escape.": "彼らは戦いたくないようだ。逃げようとしている。",
    "AUGMENTS OF THE DAY [33% OFF]": "今日の拡張機能 [33% OFF]",
    "Chaotic Renegade Cruiser": "カオス・レネゲイド巡洋艦",
    "Special loot weapon. See tooltip in the inventory to check the improvements over the base version.": "特別戦利品兵器。インベントリのツールチップを確認して、通常バージョンからの改善点を確認してください。",
    "Your new crew materializes in the room.": "新しいクルーが室内に具現化しました。",
    "You power up the machine to max and watch as a rift opens, shaking the ship until suddenly it powers off, and a flashing green light followed by a string of coordinates signifies that it has worked.": "マシンの電源を最大まで上げ、亀裂が開いて船が揺れるのを見ていると、突然電源が切れ、座標の文字列に沿って点滅する緑色のライトが正しく動作したことを示します。",
    "Do something else instead.": "代わりに他のことをする。",
    "Renegade Defeated": "撃破済みレネゲイド",
    "Boon Received": "受け取った恩恵",
    "Attack the guard.": "警備員を攻撃する。",
    "Return.": "戻る。",
    "DRONES OF THE DAY [33% OFF]": "今日のドローン [33% OFF]",
    "Modular Missile": "モジュラー・ミサイル",
    "Mod. Missile": "Mod. ミサイル",
    "We can't help.": "どうしようもない。",
    "Install the External Augment internally.": "外部拡張機能を内部にインストールする。",
    "You activate the combat augment.": "戦闘拡張機能を起動します。",
    "The crew is dead, leaving you with the ship. Its cargo is yours for the taking. Aboard is the special tech you expected, which you bring back to your ship.": "敵クルーは死亡し、敵船が残されました。その貨物はあなたのものです。自船に持ち帰った貨物には、あなたが期待していた特別な技術が搭載されていました。",
    "Ignore the station.": "ステーションを無視する。",
    "(Jerry) \"Hello!\"": "(ジェリー)\"やあ！\"",
    "Listen.": "聞く。",
    "Accept their offer.": "提案を受け入れる。",
    "Ignore the ship.": "船を無視する。",
    "Attack them.": "攻撃する。",
    "Close your eyes and relax...": "目を閉じてリラックスする……",
    "Install the Firestarter Module.": "着火モジュールをインストールする。",
    "Install the Hullbuster Module.": "対船体モジュールをインストールする。",
    "Install the Power Module.": "パワー・モジュールをインストールする。",
    "Get to Sector 5 with the Type A to unlock this ship.": "タイプAでセクター5へ到達して船をアンロックする。",
    "(Adv. Engines) Try to escape the Elite.": "(高度なエンジン)エリートから逃げる。",
    "Obyn": "オービン",
    "You decide not to do anything and prepare to fight.": "あなたは何もしないと決め、戦闘の準備をする。",
    "Get to Sector 5 with the Type B or beat the game with the Type A to unlock this ship.": "タイプBでセクター5へ到達するか、タイプAで勝利して船をアンロックする。",
    "Modular Beam": "モジュラー・ビーム",
    "Mod. Beam": "Mod. ビーム",
    "Leave them be.": "放っておく。",
    "Attack them!": "攻撃する！",
    "(Mind Control) Convince the guard to leave you alone.": "(マインド・コントロール)警備員を説得して放っておいてもらう。",
    "Nevermind, let's fight!": "何でもない、戦おう！",
    "Approach.": "近づく。",
    "Accept the job.": "仕事を受け入れる。",
    "The alarms buzz and an extra layer of security slams shut on the vault door. You quickly flee but the Zoltan reinforcements arrive just in time to fire a barrage of missiles straight through your defences before you can escape.": "警報が鳴り響き、追加のセキュリティ層が金庫室のドアを封鎖します。あなたはすぐに逃げますが、ゾルタンの増援がちょうど到着し、逃げ切る前にあなたの防御を突破してミサイルの集中砲火を発射します。",
    "L-9678": "L-9678",
    "Contact the civilian ship.": "民間船に連絡する。",
    "Install the Anti-Bio Module.": "対生体モジュールをインストールする。",
    "Install the Cooldown Module.": "冷却モジュールをインストールする。",
    "Install the Neural Module.": "ニューラル・モジュールをインストールする。",
    "Prepare to fight!": "戦闘準備！",
    "Attack the outpost!": "前哨基地を攻撃する！",
    "(Magnet Arm) Salvage the wreck further.": "(磁気アーム)さらに難破船をサルベージする。",
    "You now have some time to do something on the ship.": "船内で何かをする時間があります。",
    "\"Another day, another profit for both of ussss, eh ssstranger?\"": "\"別の日に、私達両方に別の利益が得られる、よぉそ者？\"",
    "You cannot install this lab modification, as you still have the external version.": "すでに外部バージョンがあるので、このラボ改造はインストールできません。",
    "Artillery": "弩級砲",
    "Anointed": "聖なる女王",
    "You prepare for combat.": "あなたは戦闘の準備を始めた。",
    "Ignore the guard.": "警備員を無視する。",
    "That's enough for now.": "今はそれで十分だ。",
    "Install the Accuracy Module.": "精度モジュールをインストールする。",
    "Currently Installed: None": "現在のインストール状況: なし",
    "PHEROMONE": "フェロモン",
    "Grant Received": "受け取ったギフト",
    "Blessing Received": "受け取った祝福",
    "Pirate Fighter": "海賊ファイター",
    "Task Marker": "タスクマーカー",
    "Obsidian Armor": "黒耀石アーマー",
    "Leave them alone.": "放っておく。",
    "Attack the ship.": "船を攻撃する。",
    "Dock.": "ドッキングする。",
    "\"Task accepted. Transferring coordinates to next sector. Do not disappoint me.\"": "\"タスクを受理しました。次のセクターに座標を送ります。私を失望させないでくださいね。\"",
    "From out of the tunnel comes a massive cruiser vessel, of unknown alien design! At once, a strange pattern appears on your computer... its frequency matches the signal from that beacon you had activated earlier!": "トンネルから出てきたのは、未知のエイリアンのデザインの巨大な巡洋艦です！すぐに、奇妙なパターンがコンピュータに表示されます……その周波数は、以前にあなたがアクティブ化したビーコンからの信号と一致します！",
    "You arm the weapons and engage the station!": "武器を構えてステーションと交戦を開始します！",
    "You activate the payload and launch it from the vessel.": "弾頭を起動して船舶から発射します。",
    "Set the drone to Boarding Mode.": "ドローンを搭乗モードに切り替える。",
    "Pirate Scout": "海賊スカウト",
    "Traveling Merchant": "旅商人",
    "Multiverse Flagship": "マルチバース旗艦",
    "Pay.": "支払う。",
    "You give the weapon to the engineer, allowing him to work on it.": "あなたはエンジニアに兵器を渡し、彼に作業させます。",
    "After a short time, your weapon is returned to you, clad with an optimization.": "しばらくすると、最適化された武器が返されました。",
    "Contact the guard.": "警備員に連絡する。",
    "Install the Lockdown Module.": "ロックダウン・モジュールをインストールする。",
    "You must have the lab upgrade for this modification.": "この改造にはラボのアップグレードが必要です。",
    "You begin the upgrade...": "アップグレードを開始しました……",
    "Power rerouted to surge control. Proceeding to combat.": "電力はサージ制御に再配線されました。戦闘に進みます。",
    "Your Power Surge will occur after this countdown.": "このカウントダウンの後にあなたのパワーサージが発生します。",
    "BOMB": "爆弾",
    "Pirate Outrider": "海賊アウトライダー",
    "Investigate.": "調査する。",
    "Request supplies.": "補給を要求する。",
    "Contact the refugee ship.": "難民船に連絡する。",
    "See what they're selling.": "売っているものを見る。",
    "Install the Pierce Module.": "貫通モジュールをインストールする。",
    "What upgrade do you want to install?": "どのアップグレードをインストールしますか？",
    "Your Malform transforms back to its original shape.": "あなたのマルフォームは元の形に戻っています。",
    "Attack, we can steal their Mine Launcher tech!": "攻撃、彼らのマインランチャー技術を盗める！",
    "You've taken the risky choice of fighting the ship. Hopefully, you can protect yourself from their salvo long enough.": "あなたは船と戦うという危険な選択をしました。うまくいけば、彼らの一斉射撃から十分長く耐えることができるかもしれません。",
    "Avoid the Trapper.": "トラッパーを避ける。",
    "Messing with a Trapper is a bad idea.": "トラッパーにちょっかいを出すのは悪い考えだ。",
    "Human": "人間",
    "Thing": "何か",
    "Contact the Engi.": "エンジに連絡する。",
    "Sure.": "もちろん。",
    "The ship breaks apart and you quickly salvage what you can.": "船はばらばらになり、あなたはすぐにできる限りの物を回収します。",
    "Salvage the ruins.": "残骸をサルベージする。",
    "You rig the ammunition and set a trap for the Rebels. It's definitely illegal to do, but you'll be gone before it matters.": "あなたは弾薬を装備し、反乱軍に罠を仕掛けます。それは間違いなく違法行為ですが、あなたは問題になる前に去るでしょう。",
    "Pirate Transport": "海賊輸送船",
    "Mascot": "マスコット",
    "Merchant": "商人",
    "Awesome Laser": "素晴らしいレーザー",
    "Respond.": "返答する。",
    "Attack the station!": "ステーションを攻撃する！",
    "Surrender is not an option.": "降伏という選択肢はない。",
    "\"A good choice. May it serve you well in your travels!\"": "\"良い選択です。あなたの旅のお役に立ちますように！\"",
    "Jerry": "ジェリー",
    "We have to go.": "行かなくちゃ。",
    "I should go.": "行くべきだ。",
    "Charlie": "チャーリー",
    "The haunted vessel has been eliminated. Another to check off the list this time. That is, assuming they don't pop up again from across the Multiverse looking for revenge.": "幽霊船は排除されました。彼らが復讐を求めてマルチバースの彼方から再び現れないと仮定して、今回はリストにもう一つチェックを入れます。",
    "You mute the ship and prepare for combat.": "あなたは船をミュートにし、戦闘の準備を始めます。",
    "You await your reward, but the machine buzzes and an X flashes on the screen. Better luck next time...": "あなたは報酬を待ちますが、マシンがブザー音を立て、画面にXマークが点滅します。次回に期待しましょう……",
    "Gamble again.": "もう一度ギャンブルする。",
    "System disabled successfully.": "システム無効化に成功しました。",
    "Pirate Bomber": "海賊ボンバー",
    "Tiiikaka Transport": "ティイカカ輸送船",
    "Max Health is increased to 110": "最大体力 110",
    "Ignore the planet.": "惑星を無視する。",
    "Finish them off.": "彼らを仕留める。",
    "Scrap the ship.": "船をスクラップにする。",
    "Continue.": "次へ…",
    "We aren't interested.": "私達は興味がない。",
    "Okay.": "分かった。",
    "It seems your track record has caught up to you. The guard's crew have heard enough of the crimes you've been committing, and they don't intend to let you into the sector!": "あなたの戦歴があなたに追いついたようです。警備員はあなたが犯した犯罪について十分に聞いており、そして彼らはあなたをセクターに入れるつもりはありません！",
    "You rush to defensive positions as the guard approaches menacingly.": "警備員が威圧的に近づいてくるので、あなたは慌てて防御態勢に入ります。",
    "Here we go again.": "ああ、またか。",
    "(Powerful Beam) Show the Beam to Leah.": "(強力なビーム)リアにビームを見せる。",
    "Whatever the ruins have to offer isn't worth the effort.": "廃墟が何を提供しようとも、労力に見合うものではありません。",
    "Ignore the merchant.": "商人を無視する。",
    "Yes": "はい",
    "Set the drone to Defensive Mode.": "ドローンを防御モードに切り替える。",
    "Free Mantis Elder": "フリー・マンティス長老",
    "Morph": "モーフ",
    "Active Ability: Deploys a Breach, Lockdown, and Ion Bomb at the same time": "アクティブアビリティ: ブリーチ、ロックダウン、イオンボムを同時に設置する。",
    "Recon Drone": "偵察ドローン",
    "Battle Drone": "戦闘ドローン",
    "Ignore the ships.": "船を無視する。",
    "You were asked to escort an unprepared vessel to these coordinates.": "あなたは、準備が整っていない船をこれらの座標まで護衛するよう依頼されました。",
    "Wait.": "待つ。",
    "More boarding pods are approaching!": "さらに多くの搭乗ポッドが近づいてきます！",
    "What?": "何？",
    "Your crew cannot be cloned, as you just sold them.": "クルーを売ってしまったので、クローンすることができません。",
    "With the crew dead you quickly salvage what you can.": "敵クルーは死亡し、あなたはすぐにできる限りのものをサルベージします。",
    "Contact the Monks.": "僧侶に連絡する。",
    "The slave ship is destroyed. They won't continue their evil trade, but many lives were probably lost on that ship.": "奴隷船は破壊されました。彼らの邪悪な貿易は終わりましたが、おそらく多くの命がその船で失われてしまったでしょう。",
    "Demand supplies.": "補給を要求する。",
    "Change your mind and leave the guard alone.": "考えを変えて、警備員を放っておく。",
    "You apologize and end comms. The guard makes no attempts to communicate further.": "あなたは謝罪し、通信を終了します。警備員はそれ以上コミュニケーションを取ろうとしません。",
    "This is the location of the Traveling Merchant.": "これは旅商人のいる地点です。",
    "Er... sorry?": "ええと……すみません？",
    "Buy the pen.": "ペンを買う。",
    "Rescue the store.": "店を救出する。",
    "Shop.": "買い物をする。",
    "Success, time for battle!": "成功、戦いの時間です！",
    "Buy the cargo.": "貨物を買う。",
    "The transaction is done. With the looks of it, this piece of equipment might prove useful.": "取引は完了しました。見たところ、この機材は役に立つかもしれません。",
    "Refuse and attack the transport.": "拒否し、輸送船を攻撃する。",
    "The transport captain shrugs and continues on their way.": "輸送船長は肩をすくめ、そのまま出発します。",
    "Leah": "リア"
}

mass_translate('locale/**/ja.po', REPLACE_MAP, overwrite=True)