
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using System;

public class Pencil : UdonSharpBehaviour
{

    public Transform tip;

    public Transform gunPosition;

    public GameObject debugRaycast;

    public MapStratum[] strates;

    /* FIXME Move elsewhere */
    public Camera viewCamera;

    /** Implementation */

    int currentStratum;

    RaycastHit[] hits;

    Ray ray;

    const int layerMask = (1 << 22);

    bool drawing = false;

    /* FIXME : Get this out, the pencil shouldn't manage the inventory display */
    public MeshFilter inventoryDisplay;

    /* FIXME : Get these out, the pencil shouldn't manage the save system */
    public Texture2D saveTexture;
    Color32[] texturePixels;

    private Color32 reserved;


    private Color32 ColorFromInt(int value)
    {
        return new Color32(
            (byte) ((value >>  0) & 0xff),
            (byte) ((value >>  8) & 0xff),
            (byte) ((value >> 16) & 0xff),
            (byte) ((value >> 24) & 0xff)
        );
    }

    public void SaveToTexture()
    {
        int currentPixel = saveTexture.width*4;
        for (int s = 0; s < strates.Length; s++)
        {
            int[] mapData = strates[s].map;
            for (int tile = 0; tile < mapData.Length; tile++)
            {
                texturePixels[currentPixel] = ColorFromInt(mapData[tile]);
                currentPixel++;
            }
        }
        saveTexture.SetPixels32(texturePixels);
        saveTexture.Apply(true);
    }

    private void SaveMetadata()
    {
        texturePixels[0] = new Color32((byte) 'V', (byte) 'O', (byte) 'Y', (byte) 255);
        texturePixels[1] = new Color32((byte) 'A', (byte) 'G', (byte) 'E', (byte) 255);
        texturePixels[2] = new Color32((byte) 'B', (byte) 'U', (byte) 'I', (byte) 255);
        texturePixels[3] = new Color32((byte)1,(byte)0,(byte)0,(byte)255);
        for (int i = 4; i < 16; i++)
        {
            texturePixels[i] = reserved;
        }
        saveTexture.SetPixels32(texturePixels);
        saveTexture.Apply(true);
    }

    private bool VRMode()
    {
        return Networking.LocalPlayer.IsUserInVR();
    }

    public void Start()
    {
        hits = new RaycastHit[1];

        drawing = false;
        currentStratum = 0;
        if (!VRMode())
        {
            VRC_Pickup thisPickup = (VRC_Pickup) GetComponent(typeof(VRC_Pickup));
            thisPickup.AutoHold = VRC_Pickup.AutoHoldMode.Yes;
            thisPickup.ExactGun = gunPosition;
            thisPickup.orientation = VRC_Pickup.PickupOrientation.Gun;
            thisPickup.allowManipulationWhenEquipped = false;
        }

        viewCamera.enabled = true;

        /* FIXME : Get these out, the pencil shouldn't manage the save system */
        reserved = new Color32((byte) 255, (byte) 255, (byte) 255, (byte) 255);
        texturePixels = saveTexture.GetPixels32();
        SaveMetadata();



    }

    public void NextStratum()
    {
        currentStratum += 1;
        if (currentStratum >= strates.Length)
        {
            currentStratum = 0;
        }
    }

    public void PreviousStratum()
    {
        currentStratum -= 1;
        if (currentStratum < 0)
        {
            currentStratum = (strates.Length - 1);
        }
    }

    public override void OnPickup()
    {
        drawing = true;
        /* FIXME : Get this out, the pencil shouldn't manage the inventory display */
        inventoryDisplay.sharedMesh = strates[currentStratum].displayMesh;
    }

    public override void OnDrop()
    {
        drawing = false;
    }

    float timeRemaining = 0;

    const int inventoryColumns = 8;
    const int inventoryRows = 2;
    const int invetoryRowLast = inventoryRows - 1;


    Vector2Int PosFrom1x1Grid(Vector3 hitPoint, Vector2Int nSquares, bool reverseY)
    {
        Vector3 relative = Vector3.Scale(
            hitPoint + new Vector3(0.5f,0.5f,0),
            new Vector3(nSquares.x,nSquares.y,1));
        
        int flooredY = Mathf.FloorToInt(relative.y);
        /* FIXME Find a smarter way of doing this */
        if (reverseY)
        {
            flooredY = (nSquares.y - 1) - flooredY;
        }

        int x = Mathf.Clamp(Mathf.FloorToInt(relative.x), 0, nSquares.x-1);
        int y = Mathf.Clamp(flooredY, 0, nSquares.y-1);
        return new Vector2Int(x, y);
    }

    public void FixedUpdate()
    {


        float triggerLevel = Mathf.Max(
            Input.GetAxis("Oculus_CrossPlatform_PrimaryIndexTrigger"),
            Input.GetAxis("Oculus_CrossPlatform_SecondaryIndexTrigger"));
        bool keyLevel = Input.GetMouseButton(0);

        bool firing = ((triggerLevel > 0.5) | keyLevel);

        if (!((drawing) & (firing))) return;

        ray.origin = tip.position;
        ray.direction = tip.forward;

        int n_hits = Physics.RaycastNonAlloc(ray, hits, 0.75f, layerMask);

        if (n_hits > 0)
        {
            RaycastHit hit = hits[0];
            
            Vector3 hitPoint = hits[0].point;
            debugRaycast.transform.position = hitPoint;

            string hitObjectName = hit.collider.gameObject.name;
            Vector3 localHitPoint = hit.transform.InverseTransformPoint(hitPoint);
            MapStratum stratum = strates[currentStratum];
            switch(hitObjectName)
            {
                case "DrawingPane":
                {

                    Vector2Int pos = PosFrom1x1Grid(
                        localHitPoint,
                        new Vector2Int(8,8),
                        false
                    );

                    stratum.SetTileAndBake(pos.x, pos.y);
                    
                }
                break;
                case "PartsSelect":
                {
                    /* "InverseTransformPoint is affected by Scale"
                     * Unity Official Lies - 2019.
                     */
                    /* FIXME: This only works because I KNOW that the size is 1m x 1m
                     * and that InverseTransformPoint actually IGNORES the scaling
                     * of the transform you use it from (but not the parent !)
                     */
                    Vector2Int pos = PosFrom1x1Grid(
                        localHitPoint,
                        new Vector2Int(inventoryColumns, inventoryRows),
                        true);

                    int meshIndex = pos.y * inventoryColumns + pos.x;

                    stratum.SetSelectionMeshIndex(meshIndex);

                }
                break;
                case "StrateSelectFloor":
                {
                    currentStratum = 0;
                    /* FIXME : Get this out, the pencil shouldn't manage the inventory display */
                    inventoryDisplay.sharedMesh = strates[currentStratum].displayMesh;
                }
                break;
                case "StrateSelectWalls":
                {
                    currentStratum = 1;
                    /* FIXME : Get this out, the pencil shouldn't manage the inventory display */
                    inventoryDisplay.sharedMesh = strates[currentStratum].displayMesh;
                }
                break;
                /*
                case "StratumSelect":
                {
                    Vector2Int pos = PosFrom1x1Grid(
                        localHitPoint,
                        new Vector2Int(0,2),
                        false);

                    currentStratum = pos.y;

                    invetoryDisplay.sharedMesh = strates[currentStratum].displayMesh;
                }
                break;*/
                case "TextureSelect":
                {
                    Vector2Int pos = PosFrom1x1Grid(
                        localHitPoint,
                        new Vector2Int(8,2),
                        true);
                    /* FIXME : Magic value, 8 is the number of texture tiles per row */
                    stratum.SetupMeshForTextureIndex(pos.y * 8 + pos.x);
                }
                break;
                case "DirectionUp":
                {
                    stratum.SetOrientation(0);
                }
                break;
                case "DirectionRight":
                {
                    stratum.SetOrientation(2);
                }
                break;
                case "DirectionDown":
                {
                    stratum.SetOrientation(4);
                }
                break;
                case "DirectionLeft":
                {
                    stratum.SetOrientation(6);
                }
                break;
                default: 
                {
                    Debug.Log($"Unknown name {hitObjectName}");
                }
                break;
            }


        }


    }
}
