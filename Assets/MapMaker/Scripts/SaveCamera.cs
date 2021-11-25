
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class SaveCamera : UdonSharpBehaviour
{
    public GameObject overlaySave;
     /* FIXME : Remove this, the Pencil should not handle the
      * save system !
      */
    public Pencil pencil;
    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (player == Networking.LocalPlayer)
        {
            /* FIXME : Remove this, the Pencil should not handle the
             * save system !
             */
            pencil.SaveToTexture();
            overlaySave.SetActive(true);
        }
    }

    public override void OnPlayerTriggerExit(VRCPlayerApi player)
    {
        if (player == Networking.LocalPlayer)
        {
            overlaySave.SetActive(false);
        }
    }

    /*public int currentDisplay = 0;
    public int currentEye = 0;
    public void FixedUpdate()
    {
        
        if (Input.GetKeyUp(KeyCode.KeypadPlus))
        {
            currentDisplay++;
            currentDisplay &= 7;
            overlaySaveCamera.targetDisplay = currentDisplay;
        }

        if (Input.GetKeyUp(KeyCode.KeypadMultiply))
        {
            currentEye++;
            currentEye &= 3;
            overlaySaveCamera.stereoTargetEye = (StereoTargetEyeMask) currentEye;
        }
    }*/
}
