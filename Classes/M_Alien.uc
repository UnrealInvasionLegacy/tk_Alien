class M_Alien extends tk_Monster 
	config(tk_Monsters);

#EXEC OBJ LOAD FILE="Resources/rs_Alien.u" PACKAGE="tk_Alien"

var class<EDWDamagingGib> DamageGibs[6];
var class<xEmitter> myBloodHitClass;
var bool bLunging;
var config int ClawDamage, LungeDamage;
var sound LungeSound;
var float LungeSpeed;
var float NewLungeSpeed;
var float TearThreshold;
var bool bLostHead, bLostTorso, bLostLeftLeg, bLostRightLeg, bLostLeftArm, bLostRightArm;
var float ArmAbsorb, LegAbsorb, TorsoAbsorb, HeadAbsorb;
var bool bCanLunge;
var bool bAttackSuccess;
var bool bSuperAggressive;
var name MeleeAttack[5];
var NavigationPoint UltPoint, PenUltPoint;

replication
{
	Unreliable if(Role==ROLE_Authority)
		SpawnDamagingGib;
}

function class<EDWDamagingGib> GetDamageGibClass(xPawnGibGroup.EGibType gibType)
{
	return default.DamageGibs[int(gibType)];
}

function PlayVictory()
{
	Controller.bPreparingMove = true;
	Acceleration=vect(0,0,0);
	bShotAnim=true;
    PlaySound(sound'tk_Alien.Alien.Spot_1',SLOT_Interact);
    SetAnimAction('PThrust');
	Controller.Destination = Location;
	Controller.GotoState('TacticalMove','WaitForAnim');
}

function bool SameSpeciesAs(Pawn P)
{
	If (P.isA('M_Alien')) return True;
	Else return ( (Monster(P) != None) && (ClassIsChildOf(Class,P.Class) || ClassIsChildOf(P.Class,Class)) );
}

event EndCrouch(float HeightAdjust)
{
	Super.EndCrouch(HeightAdjust);
	bCanStrafe=True;
}

event StartCrouch(float HeightAdjust)
{
	Super.StartCrouch(HeightAdjust);
	bCanStrafe=False;
}

function PlayHit(float Damage, Pawn InstigatedBy, vector HitLocation, class<DamageType> damageType, vector Momentum)
{
local Vector HitNormal;
local Vector HitRay;
local Name HitBone;
local float HitBoneDist;
local PlayerController PC;
local XPawn XInstigatedBy;
local bool bShowEffects;

	Super(Pawn).PlayHit(Damage,InstigatedBy,HitLocation,DamageType,Momentum);
    if ( Damage <= 0 )
		return;

    PC = PlayerController(Controller);
	bShowEffects = ( (Level.NetMode != NM_Standalone) || (Level.TimeSeconds - LastRenderTime < 3)
					|| ((InstigatedBy != None) && (PlayerController(InstigatedBy.Controller) != None))
					|| (PC != None) );
	if ( !bShowEffects )
		return;
    XInstigatedBy = xPawn(InstigatedBy);

    HitRay = vect(0,0,0);
    if( InstigatedBy != None )
        HitRay = Normal(HitLocation-(InstigatedBy.Location+(vect(0,0,1)*InstigatedBy.EyeHeight)));

    if( DamageType.default.bLocationalHit )
        CalcHitLoc( HitLocation, HitRay, HitBone, HitBoneDist );
    else
    {
        HitLocation = Location;
        HitBone = 'None';
        HitBoneDist = 0.0f;
    }

    if( DamageType.default.bAlwaysSevers && DamageType.default.bSpecial )
        HitBone = 'head';

	if( InstigatedBy != None )
		HitNormal = Normal( Normal(InstigatedBy.Location-HitLocation) + VRand() * 0.2 + vect(0,0,2.8) );
	else
		HitNormal = Normal( Vect(0,0,1) + VRand() * 0.2 + vect(0,0,2.8) );

	if ( DamageType.Default.bCausesBlood )
	{
		if ( class'GameInfo'.static.UseLowGore() )
			Spawn( myBloodHitClass, InstigatedBy,, HitLocation, Rotator(HitNormal) );
		else
			Spawn( myBloodHitClass,InstigatedBy,, HitLocation, Rotator(HitNormal) );
	}

	// hack for flak cannon gibbing
	if ( (DamageType.name == 'DamTypeFlakChunk') && (Health < 0) && (VSize(InstigatedBy.Location - Location) < 350) )
		DoDamageFX( HitBone, 8*Damage, DamageType, Rotator(HitNormal) );
	else
		DoDamageFX( HitBone, Damage, DamageType, Rotator(HitNormal) );

	if (DamageType.default.DamageOverlayMaterial != None && Damage > 0 ) // additional check in case shield absorbed
		SetOverlayMaterial( DamageType.default.DamageOverlayMaterial, DamageType.default.DamageOverlayTime, false );
}

simulated function ProcessHitFX()
{
    local float GibPerterbation;

    if( (Level.NetMode == NM_DedicatedServer) || class'GameInfo'.static.UseLowGore() )
        return;

    for ( SimHitFxTicker = SimHitFxTicker; SimHitFxTicker != HitFxTicker; SimHitFxTicker = (SimHitFxTicker + 1) % ArrayCount(HitFX) )
    {
        if( HitFX[SimHitFxTicker].damtype == None )
            continue;

        if( HitFX[SimHitFxTicker].bSever )
        {
            GibPerterbation = HitFX[SimHitFxTicker].damtype.default.GibPerterbation;

            switch( HitFX[SimHitFxTicker].bone )
            {
                case 'lthigh':
                case 'rthigh':
                    SpawnDamagingGib( GetDamageGibClass(EGT_Calf), Location - CollisionHeight * vect(0,0,0.5), HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    SpawnDamagingGib( GetDamageGibClass(EGT_Calf), Location - CollisionHeight * vect(0,0,0.5), HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    GibCountCalf -= 2;
                    break;

                case 'rfarm':
                case 'lfarm':
                    SpawnDamagingGib( GetDamageGibClass(EGT_UpperArm), Location + CollisionHeight * vect(0,0,0.5), HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    SpawnDamagingGib( GetDamageGibClass(EGT_Forearm), Location + CollisionHeight * vect(0,0,0.5), HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    GibCountForearm--;
                    GibCountUpperArm--;
                    break;

                case 'head':
                    SpawnDamagingGib( GetDamageGibClass(EGT_Head), Location + CollisionHeight * vect(0,0,0.8), HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    GibCountTorso--;
                    break;

                case 'spine':
                case 'none':
                    SpawnDamagingGib( GetDamageGibClass(EGT_Torso), Location, HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    GibCountTorso--;
					bGibbed = true;
                    while( GibCountHead-- > 0 )
                        SpawnDamagingGib( GetDamageGibClass(EGT_Head), Location + CollisionHeight * vect(0,0,0.8), HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    while( GibCountForearm-- > 0 )
                        SpawnDamagingGib( GetDamageGibClass(EGT_UpperArm), Location + CollisionHeight * vect(0,0,0.5), HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    while( GibCountUpperArm-- > 0 )
                        SpawnDamagingGib( GetDamageGibClass(EGT_Forearm), Location + CollisionHeight * vect(0,0,0.5), HitFX[SimHitFxTicker].rotDir, GibPerterbation );
                    bHidden = true;
                    break;
            }
        }
    }
}

function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, class<DamageType> damageType)
{
local int actualDamage;
local bool bAlreadyDead;
local Controller Killer;

local vector BoneTestLocation, X;
local float HitHorizontal, HitVertical, dist;
local name HitBone;
local coords BoneCoords;

local bool bInstantKill;

	if ( damagetype == None )
	{
		if ( InstigatedBy != None )
			warn("No damagetype for damage by "$instigatedby$" with weapon "$InstigatedBy.Weapon);
		DamageType = class'DamageType';
	}

	if ( Role < ROLE_Authority )
	{
		log(self$" client damage type "$damageType$" by "$instigatedBy);
		return;
	}

	bAlreadyDead = (Health <= 0);

	if (Physics == PHYS_None)
		SetMovementPhysics();
	if (Physics == PHYS_Walking)
		momentum.Z = FMax(momentum.Z, 0.4 * VSize(momentum));
	if ( instigatedBy == self )
		momentum *= 0.6;
	momentum = momentum/Mass;

//LOCATIONAL DAMAGE


//END LOCATIONAL DAMAGE

    if (Weapon != None)
        Weapon.AdjustPlayerDamage( Damage, InstigatedBy, HitLocation, Momentum, DamageType );
    if ( (InstigatedBy != None) && InstigatedBy.HasUDamage() ) // FIXME THIS SUCKS
        Damage *= 2;
	actualDamage = Level.Game.ReduceDamage(Damage, self, instigatedBy, HitLocation, Momentum, DamageType);
	if( DamageType.default.bArmorStops && (actualDamage > 0) )
		actualDamage = ShieldAbsorb(actualDamage);

	if(InstigatedBy!=None&&!bAlreadyDead)
	{
		X=InstigatedBy.Location-Location;

		//Find the closest bone.
		HitBone = GetClosestBone(Hitlocation, X, dist, 'head', 10);

		if(HitBone != 'head')
			HitBone = GetClosestBone(Hitlocation, X, dist, 'spine', 21);

		if(HitBone!='spine')
			HitBone=GetClosestBone(Hitlocation, X, dist);

		//Caters for monsters, and anything else without any bones.

		if(HitBone =='None')
		{
			BoneTestLocation=HitLocation;
			HitVertical = HitLocation.Z - Location.Z;
			BoneTestLocation.Z = Location.Z;
			HitHorizontal = VSize(BoneTestLocation - Location);

			if(HitHorizontal < CollisionRadius * 0.5)
			{
				if(HitVertical > CollisionHeight * 0.9)
					HitBone = 'head';
				else if(HitVertical > CollisionHeight * -0.4)
					HitBone = 'spine';
			}
		}

		if(HitBone == 'head')
		{
	//		log("Head:"@HitBone);
			ActualDamage*=HeadAbsorb;
			if(ActualDamage>=TearThreshold*2&&!bLostHead)
			{
				SetHeadScale(0.0);
				bLostHead=True;
				ActualDamage=Health+1;
				bInstantKill=True;
				boneCoords=GetBoneCoords('head');
				SpawnDamagingGib(GetDamageGibClass(EGT_Head), boneCoords.Origin, rotator(x), 0.5 );
			}
		}

		else if(HitBone == 'spine')
		{
	//		log("Torso:"@HitBone);
			ActualDamage*=TorsoAbsorb;
			if(ActualDamage>=TearThreshold*3&&!bLostTorso)
			{
				HideBone(HitBone);
				bLostTorso=True;
				ActualDamage*=80;
				bInstantKill=True;
				boneCoords=GetBoneCoords('spine');
				SpawnDamagingGib(GetDamageGibClass(EGT_Torso), boneCoords.Origin, Rotator(x), 0.5 );
			}
		}

		else if(HitBone=='lthigh'||HitBone=='lfoot')
		{
	//		log("Left Leg:"@HitBone);
			ActualDamage*=LegAbsorb;
			if(ActualDamage>=TearThreshold&&!bLostLeftLeg)
			{
				HideBone(HitBone);
				bLostLeftLeg=True;
				GroundSpeed=800; //0.7
				LungeSpeed=300; //0.8
				boneCoords=GetBoneCoords(HitBone);
				SpawnDamagingGib(GetDamageGibClass(EGT_Calf), boneCoords.Origin, Rotator(x), 0.5 );
			}
		}

		else if(HitBone=='rthigh'||HitBone=='rfoot')
		{
	//		log("Right Leg:"@HitBone);
			ActualDamage*=LegAbsorb;
			if(ActualDamage>=TearThreshold&&!bLostRightLeg)
			{
				HideBone(HitBone);
				bLostRightLeg=True;
				GroundSpeed=800.0; //0.7
				LungeSpeed=300.0; //0.8
				boneCoords=GetBoneCoords(HitBone);
				SpawnDamagingGib(GetDamageGibClass(EGT_Calf), boneCoords.Origin, Rotator(x), 0.5 );
			}
		}

		else if(HitBone=='lshoulder'||HitBone=='lfarm'||HitBone=='lhand')
		{
	//		log("Left Arm:"@HitBone);
			ActualDamage*=ArmAbsorb;
			if(ActualDamage>=TearThreshold&&!bLostLeftArm)
			{
				HideBone(HitBone);
				bLostLeftArm=True;
				ClawDamage*=0.75;
				LungeDamage*=0.75;
				boneCoords=GetBoneCoords(HitBone);
				SpawnDamagingGib(GetDamageGibClass(EGT_UpperArm), boneCoords.Origin, Rotator(x), 0.5 );
			}
		}

		else if(HitBone=='rshoulder'||HitBone=='rfarm'||HitBone=='rhand')
		{
	//		log("Right Arm:"@HitBone);
			ActualDamage*=ArmAbsorb;
			if(ActualDamage>=TearThreshold&&!bLostRightArm)
			{
				HideBone(HitBone);
				bLostRightArm=True;
				ClawDamage*=0.75;
				LungeDamage*=0.75;
				boneCoords=GetBoneCoords(HitBone);
				SpawnDamagingGib(GetDamageGibClass(EGT_Upperarm), boneCoords.Origin, Rotator(x), 0.5 );
			}
		}

		if(bLostLeftLeg&&bLostRightLeg)
			bInstantKill=True;
	}

	if(bInstantKill)		//Hack to make sure aliens die when you decapitate them, pop their torso, or remove both their legs
		actualDamage=Max(Damage,Health);

	Health -= actualDamage;
	if ( HitLocation == vect(0,0,0) )
		HitLocation = Location;
	if ( bAlreadyDead )
		return;

	PlayHit(actualDamage,InstigatedBy, hitLocation, damageType, Momentum);
	if ( Health <= 0 )
	{
		// pawn died
		if ( instigatedBy != None )
			Killer = instigatedBy.GetKillerController();
		else if ( (DamageType != None) && DamageType.Default.bDelayedDamage )
			Killer = DelayedDamageInstigatorController;
		if ( bPhysicsAnimUpdate )
			TearOffMomentum = momentum;
		Died(Killer, damageType, HitLocation);
	}
	else
	{
		AddVelocity( momentum );
		if ( Controller != None )
			Controller.NotifyTakeHit(instigatedBy, HitLocation, actualDamage, DamageType, Momentum);
	}
	MakeNoise(1.0);
}


simulated function SpawnDamagingGib (class<EDWDamagingGib> GibClass, vector location, rotator Rotation, float Gibperterbation)
{
local EDWDamagingGib Gibletzorz;
local vector Direction, Dummy;

	if(Gibclass==None)
		return;

	instigator=self;
	Gibletzorz=spawn(GibClass,,, Location, Rotation);

	if(Gibletzorz==None)
		return;

	GibPerterbation*=32768.0;
	Rotation.Pitch+=(FRand()*2.0*GibPerterbation)-GibPerterbation;
	Rotation.Yaw+=(FRand()*2.0*GibPerterbation)-Gibperterbation;
	Rotation.Roll+=(FRand()*2.0*GibPerterbation)-GibPerterbation;

	GetAxes(Rotation, dummy, dummy, direction);

	Gibletzorz.Velocity=Velocity+Normal(Direction)*320.0;
}


simulated function SpawnGiblet( class<Gib> GibClass, Vector Location, Rotator Rotation, float GibPerterbation )
{
}

simulated function ChunkUp( Rotator HitRotation, float ChunkPerterbation ) // gam
{
	Super(UnrealPawn).ChunkUp(HitRotation, ChunkPerterbation);
}

simulated function SpawnGibs(Rotator HitRotation, float ChunkPerterbation)
{
	bGibbed = true;
	PlayDyingSound();
	if( GibCountTorso+GibCountHead+GibCountForearm+GibCountUpperArm > 3 )
	{
		if ( class'GameInfo'.static.UseLowGore() )
			Spawn( GibGroupClass.default.LowGoreBloodGibClass,,,Location );
		else
			Spawn( GibGroupClass.default.BloodGibClass,,,Location );
	}
	if ( class'GameInfo'.static.UseLowGore() )
		return;

	SpawnDamagingGib( GetDamageGibClass(EGT_Torso), Location, HitRotation, ChunkPerterbation );
	GibCountTorso--;

	while( GibCountTorso-- > 0 )
		SpawnDamagingGib( GetDamageGibClass(EGT_Torso), Location, HitRotation, ChunkPerterbation );
	while( GibCountHead-- > 0 )
		SpawnDamagingGib( GetDamageGibClass(EGT_Head), Location, HitRotation, ChunkPerterbation );
	while( GibCountForearm-- > 0 )
		SpawnDamagingGib( GetDamageGibClass(EGT_UpperArm), Location, HitRotation, ChunkPerterbation );
	while( GibCountUpperArm-- > 0 )
		SpawnDamagingGib( GetDamageGibClass(EGT_Forearm), Location, HitRotation, ChunkPerterbation );
}

singular function Bump(actor Other)
{
local name Anim;
local float frame,rate;

	if ( bShotAnim && bLunging )
	{
		GetAnimParams(0, Anim,frame,rate);
		if ( Anim == 'JumpF_Takeoff' )
		{
			MeleeDamageTarget(LungeDamage, (20000.0 * Normal(Controller.Target.Location - Location)));
			bLunging=false;
			bShotAnim=False;
			Disable('Bump');
			Return;
		}
	}
	Super.Bump(Other);
}

function RangedAttack(Actor A)
{
local float Dist;

	if (bShotAnim||Physics==PHYS_Falling)
		return;

	Dist = VSize(A.Location - Location);
	if ( Dist > 350 )
		return;
	bShotAnim = true;
	PlaySound(ChallengeSound[Rand(4)], SLOT_Interact);
	if ( Dist < MeleeRange + CollisionRadius + A.CollisionRadius )
	{
  		if ( FRand() < 0.5 )
  			SetAnimAction('JumpF_Takeoff');
  		else
		SetAnimAction(MeleeAttack[Rand(5)]);
		MeleeDamageTarget(ClawDamage, vect(0,0,0));
		Controller.bPreparingMove = true;
		Acceleration = vect(0,0,0);
		return;

	}
	bLunging = true;
	Enable('Bump');
	SetAnimAction('JumpF_Takeoff');
	Velocity = LungeSpeed * Normal(A.Location + A.CollisionHeight * vect(0,0,0.75) - Location);
	if ( dist > CollisionRadius + A.CollisionRadius + 35 )
		Velocity.Z += 0.45 * dist;
	SetPhysics(PHYS_Falling);
}

defaultproperties
{
     DamageGibs(0)=Class'tk_Alien.DamageGibCalf'
     DamageGibs(1)=Class'tk_Alien.DamageGibForearm'
     DamageGibs(2)=Class'tk_Alien.DamageGibForearm'
     DamageGibs(3)=Class'tk_Alien.DamageGibHead'
     DamageGibs(4)=Class'tk_Alien.DamageGibTorso'
     DamageGibs(5)=Class'tk_Alien.DamageGibUpperArm'
     myBloodHitClass=Class'tk_Alien.EDWAlienSmallHit'
     ClawDamage=10
     LungeDamage=20
     LungeSound=Sound'tk_Alien.Alien.spot_1'
     LungeSpeed=675.000000
     NewLungeSpeed=200.000000
     TearThreshold=10.000000
     ArmAbsorb=0.900000
     LegAbsorb=0.900000
     TorsoAbsorb=0.750000
     HeadAbsorb=3.000000
     bCanLunge=True
     MeleeAttack(0)="CrawlSwipeR"
     MeleeAttack(1)="CrawlSwipeL"
     MeleeAttack(2)="SwipeRight"
     MeleeAttack(3)="SwipeLeft"
     MeleeAttack(4)="SwipeCombo"
     IdleRestAnim="PThrust"
     HitSound(0)=Sound'tk_Alien.Alien.2pain_1'
     HitSound(1)=Sound'tk_Alien.Alien.pain_1'
     HitSound(2)=Sound'tk_Alien.Alien.pain_0'
     HitSound(3)=Sound'tk_Alien.Alien.pain_1'
     DeathSound(0)=Sound'tk_Alien.Alien.death_0'
     DeathSound(1)=Sound'tk_Alien.Alien.death_1'
     DeathSound(2)=Sound'tk_Alien.Alien.death_2'
     DeathSound(3)=Sound'tk_Alien.Alien.death_3'
     ChallengeSound(0)=Sound'tk_Alien.Alien.2attack_0'
     ChallengeSound(1)=Sound'tk_Alien.Alien.attackswipe_1'
     ChallengeSound(2)=Sound'tk_Alien.Alien.attackswipe_2'
     ChallengeSound(3)=Sound'tk_Alien.Alien.spot_1'
     ScoringValue=10
     GibGroupClass=Class'tk_Alien.xAlienGibGroup'
     SoundGroupClass=Class'tk_Alien.XenoSoundGroup'
     IdleHeavyAnim="PThrust"
     IdleRifleAnim="ThroatCut"
     RagdollLifeSpan=25.000000
     RagInvInertia=5.000000
     RagDeathVel=300.000000
     RagDeathUpKick=200.000000
     bCanCrouch=True
     bMuffledHearing=False
     bAroundCornerHearing=True
     MaxDesiredSpeed=1400.000000
     MeleeRange=110.000000
     GroundSpeed=900.000000
     JumpZ=100.000000
     Health=150
     MovementAnims(0)="Crawl"
     MovementAnims(1)="Crawl"
     MovementAnims(2)="Crawl"
     MovementAnims(3)="Crawl"
     TurnLeftAnim="Crawl"
     TurnRightAnim="Crawl"
     SwimAnims(0)="SwimB"
     SwimAnims(2)="SwimB"
     SwimAnims(3)="SwimB"
     CrouchAnims(0)="Crawl"
     CrouchAnims(1)="Crawl"
     CrouchAnims(2)="Crawl"
     CrouchAnims(3)="Crawl"
     WalkAnims(0)="Crawl"
     WalkAnims(1)="Crawl"
     WalkAnims(2)="Crawl"
     WalkAnims(3)="Crawl"
     AirAnims(0)="JumpF_Mid"
     AirAnims(1)="JumpB_Mid"
     AirAnims(2)="JumpL_Mid"
     AirAnims(3)="JumpR_Mid"
     TakeoffAnims(0)="JumpF_Takeoff"
     TakeoffAnims(1)="JumpB_Takeoff"
     TakeoffAnims(2)="JumpL_Takeoff"
     TakeoffAnims(3)="JumpR_Takeoff"
     LandAnims(0)="JumpF_Land"
     LandAnims(1)="JumpB_Land"
     LandAnims(2)="JumpL_Land"
     LandAnims(3)="JumpR_Land"
     DoubleJumpAnims(0)="PThrust"
     DoubleJumpAnims(1)="PThrust"
     DoubleJumpAnims(2)="PThrust"
     DoubleJumpAnims(3)="PThrust"
     DodgeAnims(0)="DodgeF"
     DodgeAnims(1)="DodgeB"
     DodgeAnims(2)="DodgeL"
     DodgeAnims(3)="DodgeR"
     AirStillAnim="Jump_Mid"
     TakeoffStillAnim="CrawlIdle"
     CrouchTurnRightAnim="Crawl"
     CrouchTurnLeftAnim="Crawl"
     IdleCrouchAnim="gesture_cheer"
     IdleWeaponAnim="Gesture_Taunt01"
     Mesh=SkeletalMesh'tk_Alien.Alien.Alien'
     DrawScale=1.400000
     PrePivot=(Z=0.000000)
     Skins(0)=FinalBlend'tk_Alien.Alien.EDWAlienFB'
     Skins(1)=FinalBlend'tk_Alien.Alien.EDWAlienFB'
     bShadowCast=True
     CollisionHeight=59.000000
}
