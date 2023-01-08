class EDWDamagingGib extends Projectile;

var class<xEmitter> TrailClass, BounceDecalClass;
var sound HitSound;
var xEmitter Trail;
var float DampenFactor;

simulated function Destroyed()
{
    if (Trail!=None)
        Trail.mRegen=false;

	Super.Destroyed();
}

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();

    if ( Level.NetMode != NM_DedicatedServer )
    {
		Trail = Spawn(TrailClass, self,, Location, Rotation);
		Trail.SetPhysics( PHYS_Trailer );
		Trail.LifeSpan = 1.5;
		RandSpin( 64000 );
	}

    if(PhysicsVolume.bWaterVolume)
		AmbientSound=sound'GibImpactHiss';
}

simulated function ProcessTouch (Actor Other, vector HitLocation)
{
	if (Other == Instigator) return;
	if (Other == Owner) return;

	if(!Other.IsA('Projectile')||Other.bProjTarget)
	{
		if(Role==ROLE_Authority&&M_Alien(Other)==None)
			Other.TakeDamage(Damage,Instigator,HitLocation, MomentumTransfer*Normal(Velocity),MyDamageType);
		HitWall(Normal(HitLocation), Other);
	}
}

simulated function Landed( Vector HitNormal )
{
    HitWall( HitNormal, None );
}

simulated function HitWall( Vector HitNormal, Actor Wall )
{
// local float Speed;

	Velocity=DampenFactor*((Velocity dot HitNormal)*HitNormal*(-2.0)+Velocity);
	RandSpin(100000);
	Speed=VSize(Velocity);

	if( Speed > 150 )
	{
		if(Pawn(Wall)==None)
			Spawn(BounceDecalClass,,, Location, Rotator(-HitNormal) );
		if ( (Level.NetMode != NM_DedicatedServer) && (Level.DetailMode != DM_Low) && !Level.bDropDetail && (LifeSpan < 7.3) )
			PlaySound(HitSound,SLOT_None,2.5*TransientSoundVolume, True);
	}

	if( Speed < 20 )
	{
		if(Pawn(Wall)==None)
			Spawn(BounceDecalClass,,, Location, Rotator(-HitNormal) );
		bBounce = False;
		AmbientSound=HitSound;
		SetPhysics(PHYS_None);
		LifeSpan=3.0;
    }
}

defaultproperties
{
     BounceDecalClass=Class'tk_Alien.EDWAlienSmallHit'
     HitSound=Sound'tk_Alien.Alien.GibImpactHiss'
     DampenFactor=0.650000
     Damage=4.000000
     MyDamageType=Class'tk_Alien.DamTypeAcidBurn'
     Physics=PHYS_Falling
     LifeSpan=8.000000
     TransientSoundVolume=0.970000
     TransientSoundRadius=400.000000
     bBounce=True
     bFixedRotationDir=True
     Mass=30.000000
}
