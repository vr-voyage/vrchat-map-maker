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

    private int[] map;

    private CombineInstance[] stratumCombiner;

    public Mesh currentSelection;
    
    private CombineInstance[] combineCopy;
    private Matrix4x4 positionZero;

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

    void Start()
    {
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
    }

    void BakeMesh()
    {
        Mesh mesh = new Mesh();
        mesh.CombineMeshes(stratumCombiner);
        rendererFilter.sharedMesh = mesh;
        currentBakedMesh = mesh;
    }

    void SetupMeshForTextureIndex(int textureIndex)
    {
        Color32[] colors = new Color32[currentSelection.vertices.Length];
        int colorsCount = colors.Length;

        for (int i = 0; i < colorsCount; i++)
        {
            Color32 color = colors[i];
            color.r = (byte) textureIndex;
            colors[i] = color;
        }

        currentSelection.colors32 = colors;
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