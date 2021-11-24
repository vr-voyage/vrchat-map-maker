using System;
using UnityEngine;
using UdonSharp;


public class MapStratum : UdonSharpBehaviour
{
    public int nTilesX;
    public int nTilesY;

    public Mesh[] library;
    public MeshFilter rendererFilter;


    /** Implementation */

    private int maskX;
    private int maskY;

    public int[] map;

    /* FIXME :
     * I'm making this public since the Garbage Collector will
     * try to actively remove Mesh References referenced here
     * when set to private.
     * So I'm trying to put the whole collection as "public"
     * in order to stop the GC from collecting the data there.
     * We'll see if this works though..
     */
    public CombineInstance[] stratumCombiner;

    public Mesh currentSelection;
    
    public CombineInstance[] combineCopy;
    private Matrix4x4 positionZero;

    private CombineInstance[] libraryDisplay;

    private int currentMeshIndex = 0;
    private int currentTextureIndex = 0;
    private int currentOrientation = 0;
    private Matrix4x4 currentRotation;
    private Vector3 position;
    const int orientationMask   = 7;
    private int currentTileValue = 0;

    private Mesh currentBakedMesh;
    

    private int lastTileSet = -1;

    Mesh CopyMesh(Mesh meshToCopy)
    {

        CombineInstance ci = combineCopy[0];
        ci.mesh      = meshToCopy;
        combineCopy[0] = ci;
        Mesh newMesh = new Mesh();
        newMesh.CombineMeshes(combineCopy);

        return newMesh;

    }

    void InitializeMap()
    {
        map = new int[nTilesX * nTilesY];
        int map_size = map.Length;
        
        for (int i = 0; i < map_size; i++)
        {
            map[i] = 0;
        }
    }

    void InitializeCombiner()
    {
        int map_size = map.Length;
        stratumCombiner = new CombineInstance[map_size];
        
        for (int i = 0; i < map_size; i++)
        {
            CombineInstance tileData = stratumCombiner[i];
            tileData.mesh = library[0];
            tileData.transform = positionZero;
            stratumCombiner[i] = tileData;
        }

        /* FIXME 
         * This only works with power of 2 aligned values !
         * However maskX and maskY are not automatically
         * aligned on power of 2 values !
         */
        maskX =  nTilesX - 1;
        maskY  = nTilesY - 1;
    }

    public void Start()
    {
        nTilesX = (nTilesX > 0 ? nTilesX : 8);
        nTilesY = (nTilesY > 0 ? nTilesY : 8);
        currentSelection = new Mesh();
        position = new Vector3(0,0,0);
        positionZero = Matrix4x4.Translate(position);

        currentRotation = Matrix4x4.Rotate(Quaternion.identity);
        

        combineCopy = new CombineInstance[1];
        CombineInstance copyValue = combineCopy[0];
        copyValue.transform = positionZero;
        combineCopy[0] = copyValue;

        if (library == null || library.Length < 1)
        {
            Debug.LogError("MapStratum - Passed an empty library");
            library = new Mesh[1];
        }

        library[0] = new Mesh();
        
        InitializeMap();
        InitializeCombiner();

        BakeMesh();
        SetSelectionMeshIndex(1);


        /* FIXME Get this out. The map stratum shouldn't maange inventory display */
        displayMesh = new Mesh();
        InitializeLibraryDisplay();
    }


    public Mesh displayMesh;
    /* FIXME Get this out. The map stratum shouldn't maange inventory display */
    void InitializeLibraryDisplay()
    {
        libraryDisplay = new CombineInstance[library.Length];
        for (int i = 0; i < library.Length; i++)
        {
            Mesh m = library[i];
            CombineInstance ci = new CombineInstance();
            ci.mesh = m;
            int pos = (i & 7);
            Vector3 position = new Vector3(pos * 1.75f, 0,  (i / 8));
            Debug.Log($"{pos}");
            ci.transform = Matrix4x4.Translate(position);  
            libraryDisplay[i] = ci;

        }
        displayMesh = new Mesh();
        displayMesh.CombineMeshes(libraryDisplay);
    }
    

    void BakeMesh()
    {
        Mesh mesh = new Mesh();
        mesh.CombineMeshes(stratumCombiner);
        rendererFilter.sharedMesh = mesh;
        currentBakedMesh = mesh;
    }

    public void SetupMeshForTextureIndex(int textureIndex)
    {
        Mesh newMesh = CopyMesh(currentSelection);
        Color32[] colors = new Color32[newMesh.vertices.Length];
        int colorsCount = colors.Length;

        for (int i = 0; i < colorsCount; i++)
        {
            Color32 color = colors[i];
            color.r = (byte) textureIndex;
            colors[i] = color;
        }

        newMesh.colors32 = colors;
        currentSelection = newMesh;
        currentTextureIndex = textureIndex;
        ComputeTileValue();
    }

    public void SetSelectionMeshIndex(int meshIndex)
    {
        int usedIndex = Mathf.Min(meshIndex, library.Length-1);
        
        currentSelection = CopyMesh(library[usedIndex]);
        currentMeshIndex = usedIndex;
        SetupMeshForTextureIndex(currentTextureIndex);
        ComputeTileValue();
    }

    public void SetOrientation(int orientation45deg)
    {
        currentOrientation = (orientation45deg & orientationMask);
        int degrees = (currentOrientation * 45);
        currentRotation = Matrix4x4.Rotate(Quaternion.Euler(0,degrees,0));
        ComputeTileValue();
    }

    public void NextOrientation()
    {
        SetOrientation(currentOrientation + 2);
    }

    public void PreviousOrientation()
    {
        SetOrientation(currentOrientation - 2);
    }

    void ComputeTileValue()
    {
        currentTileValue = (
            currentOrientation  << 16 |
            currentTextureIndex << 08 |
            currentMeshIndex    << 00
        );
    }

    public bool SetTile(int x, int y)
    {
        
        int actual_x = Mathf.Clamp(x, 0, nTilesX - 1);
        int actual_y = Mathf.Clamp(y, 0, nTilesY - 1);

        int linear_position = actual_y * nTilesX + actual_x;

        if (lastTileSet == linear_position) 
        {
            return false;
        }

        map[linear_position] = currentTileValue;

        position.x = actual_x;
        position.z = actual_y;

        CombineInstance tileDefinition = stratumCombiner[linear_position];

        tileDefinition.mesh      = currentSelection;
        tileDefinition.transform = Matrix4x4.Translate(position) * currentRotation;

        stratumCombiner[linear_position] = tileDefinition;

        return true;
    }

    public void SetTileAndBake(int x, int y)
    {
        if (SetTile(x, y))
        {
            BakeMesh();
        }
    }

}