class EDWBioDecal extends xScorch;

simulated function BeginPlay()
{
	if ( !Level.bDropDetail && (FRand() < 0.5) )
		ProjTexture=texture'tk_Alien.AlienQueen.XenoBloodClampedToo';
	Super.BeginPlay();
}

defaultproperties
{
     ProjTexture=Texture'tk_Alien.AlienQueen.XenoBloodClamped'
     bClipStaticMesh=True
     DrawScale=0.650000
}
