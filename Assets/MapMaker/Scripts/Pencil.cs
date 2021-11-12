
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class Pencil : UdonSharpBehaviour
{

    public Transform tip;

    public Transform pane;

    public GameObject debugRaycast;

    public MeshBaker mapSystem;

    RaycastHit[] hits;

    Ray ray;

    int layerMask = 0x400000;

    bool drawing = false;

    void Start()
    {
        //layerMask = LayerMask.GetMask(new string[] { "Nawak" });
        Debug.Log($"{layerMask}");
        hits = new RaycastHit[1];

        drawing = false;
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

    Vector3 a = new Vector3(0.1f,0,0);

    void FixedUpdate()
    {
        a.x = Time.deltaTime * 1000;


        timeRemaining -= Time.deltaTime;

        if (!((timeRemaining <= 0) & (drawing))) return;

        timeRemaining = 0.03f;

        ray.origin = tip.position;
        ray.direction = tip.forward;

        int n_hits = Physics.RaycastNonAlloc(ray, hits, 0.75f, layerMask);
        //Debug.DrawRay(ray.origin, ray.direction, Color.red, 10);
        if (n_hits > 0)
        {
            a.y = 1.0f;
            RaycastHit hit = hits[0];
            
            debugRaycast.transform.position = hit.point;

            Vector3 position = hit.point;
            //Vector3 relative = position - pane.position;
            Vector3 relative = pane.InverseTransformPoint(hit.point);
            int x = Mathf.FloorToInt(relative.x*10) + 4;
            int y = Mathf.FloorToInt(relative.y*10) + 4;
            
            mapSystem.SetMapTile(x, y);
        }
        else
        {
            a.z = Random.Range(0.1f,0.5f);
        }

        //debugRaycast.transform.localPosition = a;
    }
}
