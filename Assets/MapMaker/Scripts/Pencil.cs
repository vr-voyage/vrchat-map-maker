
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class Pencil : UdonSharpBehaviour
{

    public Transform tip;

    public Transform pane;

    public GameObject debugRaycast;

    public MapStratum[] strates;

    /** Implementation */

    int currentStratum;

    RaycastHit[] hits;

    Ray ray;

    const int layerMask = ((1 << 25) | (1 << 24) | (1 << 23) | (1 << 22));

    bool drawing = false;

    void Start()
    {
        //layerMask = LayerMask.GetMask(new string[] { "Nawak" });
        Debug.Log($"{layerMask}");
        hits = new RaycastHit[1];

        drawing = false;
        currentStratum = 0;
        if (!Networking.LocalPlayer.IsUserInVR())
        {
            ((VRC_Pickup) GetComponent(typeof(VRC_Pickup))).AutoHold = VRC_Pickup.AutoHoldMode.Yes;
        }

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
        Debug.Log($"{drawing}");
    }

    public override void OnDrop()
    {
        drawing = false;
        Debug.Log($"{drawing}");
    }

    float timeRemaining = 0;

    const int inventoryColumns = 8;
    const int inventoryRows = 2;

    void FixedUpdate()
    {


        timeRemaining -= Time.deltaTime;

        float triggerLevel = Mathf.Max(
            Input.GetAxis("Oculus_CrossPlatform_PrimaryIndexTrigger"),
            Input.GetAxis("Oculus_CrossPlatform_SecondaryIndexTrigger"));
        bool keyLevel = Input.GetMouseButton(0);

        bool firing = ((triggerLevel > 0.5) | keyLevel);

        if (!((timeRemaining <= 0) & (drawing) & (firing))) return;

        timeRemaining = 0.03f;

        ray.origin = tip.position;
        ray.direction = tip.forward;

        int n_hits = Physics.RaycastNonAlloc(ray, hits, 0.75f, layerMask);
        //Debug.DrawRay(ray.origin, ray.direction, Color.red, 10);
        if (n_hits > 0)
        {
            RaycastHit hit = hits[0];
            
            debugRaycast.transform.position = hit.point;

            Vector3 position = hit.point;
            //Vector3 relative = position - pane.position;


            int hitLayer = hit.collider.gameObject.layer;
            MapStratum stratum = strates[currentStratum];
            switch(hitLayer)
            {
                case 22:
                {
                    Vector3 relative = pane.InverseTransformPoint(hit.point);
                    int x = Mathf.FloorToInt(relative.x*10) + 4;
                    int y = Mathf.FloorToInt(relative.y*10) + 4;
                    
                    stratum.SetTileAndBake(x, y);
                }
                break;
                case 23:
                {
                    Vector3 relative = hit.textureCoord;
                    int x = Mathf.Min(Mathf.FloorToInt((relative.x)*inventoryColumns), inventoryColumns-1);
                    // Start from the top (1), instead of the bottom
                    int y = Mathf.Min(Mathf.FloorToInt((1-relative.y)*inventoryRows), inventoryRows-1);

                    int meshIndex = y * inventoryColumns + x;

                    stratum.SetSelectionMeshIndex(meshIndex);
                }
                break;
                case 24:
                {
                    Vector3 relative = hit.textureCoord;
                    int y = Mathf.Clamp(Mathf.FloorToInt(relative.y*strates.Length), 0, strates.Length-1);

                    currentStratum = y;
                }
                break;
                case 25:
                {
                    Vector3 relative = hit.textureCoord;
                    int x = Mathf.Clamp(Mathf.FloorToInt(relative.x*8), 0, 8-1);

                    stratum.SetOrientation(x);

                }
                break;
                default: 
                {
                    Debug.Log($"Invalid layer {hitLayer}");
                }
                break;
            }


        }


    }
}
