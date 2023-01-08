class M_AlienQueen extends tk_Monster 
    config(tk_Monsters);

var class<EDWDamagingGib> DamageGibs[6];
var class<xEmitter> myBloodHitClass;
var bool bLunging;
var config int ClawDamage, LungeDamage;
var sound LungeSound;
var float LungeSpeed;
var float NewLungeSpeed;
var float HeadShotRadius, TorsoShotRadius;
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
	If (P.isA('M_AlienQueen')) return True;
	Else return ( (Monster(P) != None) && (ClassIsChildOf(Class,P.Class) || ClassIsChildOf(P.Class,Class)) );
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

simulated function ChunkUp( Rotator HitRotation, float ChunkPerterbation )
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
     ClawDamage=30
     LungeDamage=20
     LungeSound=Sound'tk_Alien.Alien.spot_1'
     LungeSpeed=675.000000
     NewLungeSpeed=200.000000
     HeadShotRadius=10.000000
     TorsoShotRadius=30.000000
     TearThreshold=30.000000
     ArmAbsorb=0.600000
     LegAbsorb=0.550000
     TorsoAbsorb=0.330000
     HeadAbsorb=1.100000
     bCanLunge=True
     MeleeAttack(0)="CrawlSwipeR"
     MeleeAttack(1)="CrawlSwipeL"
     MeleeAttack(2)="SwipeRight"
     MeleeAttack(3)="SwipeLeft"
     MeleeAttack(4)="SwipeCombo"
     IdleRestAnim="PThrust"
     HitSound(0)=Sound'tk_Alien.Alien.4pain_1'
     HitSound(1)=Sound'tk_Alien.Alien.4spot_1'
     HitSound(2)=Sound'tk_Alien.Alien.4spot_0'
     HitSound(3)=Sound'tk_Alien.Alien.4pain_1'
     DeathSound(0)=Sound'tk_Alien.Alien.queenscream1'
     DeathSound(1)=Sound'tk_Alien.Alien.4death_0'
     DeathSound(2)=Sound'tk_Alien.Alien.4death_1'
     DeathSound(3)=Sound'tk_Alien.Alien.queenscream1'
     ChallengeSound(0)=Sound'tk_Alien.Alien.4attack_0'
     ChallengeSound(1)=Sound'tk_Alien.Alien.attackswipe_3'
     ChallengeSound(2)=Sound'tk_Alien.Alien.attackswipe_4'
     ChallengeSound(3)=Sound'tk_Alien.Alien.4attack_1'
     ScoringValue=20
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
     MeleeRange=140.000000
     GroundSpeed=800.000000
     JumpZ=100.000000
     Health=600
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
     Mesh=SkeletalMesh'tk_Alien.AlienQueen.AlienQueen'
     DrawScale=1.600000
     PrePivot=(Z=-22.000000)
     Skins(0)=FinalBlend'tk_Alien.AlienQueen.EDWQueenFB'
     Skins(1)=FinalBlend'tk_Alien.AlienQueen.EDWQueenFB'
     bShadowCast=True
     CollisionRadius=45.000000
     CollisionHeight=105.000000
     Mass=500.000000
}
