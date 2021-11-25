#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using UnityEngine.Rendering;

namespace Myy
{
    public class QuadGenerator : EditorWindow
    {


        public string meshName;
        public Vector3[] points;
        private SerializedProperty pointsSerialized;
        public Vector2[] uvs;
        private SerializedProperty uvsSerialized;


        private SerializedObject serialO;
        private SerializedProperty meshNameSerialized;

        private void OnEnable()
        {


            serialO = new SerializedObject(this);
            meshNameSerialized = serialO.FindProperty("meshName");

            points = new Vector3[4] { new Vector3(-1,1,0), new Vector3(1,1,0), new Vector3(-1,-1,0), new Vector3(1,-1,0) };
            pointsSerialized = serialO.FindProperty("points");

            uvs = new Vector2[4] { new Vector2(0,1), new Vector2(1,1), new Vector2(0,0), new Vector2(1,0) };
            uvsSerialized = serialO.FindProperty("uvs");

        }

        Mesh GenerateSquare()
        {
            
            Color32 white = new Color32(255,255,255,255);
            Vector3 normDir = -Vector3.forward;

            Vector3[] normals =
            {
                normDir, normDir, normDir, normDir
            };
            Color32[] colors =
            {
                white,white,white,white
            };

             int[] triangles =
            {
                0,1,2,
                3,2,1
            };
            Mesh mesh      = new Mesh();
            mesh.vertices  = points;
            mesh.normals   = normals;
            mesh.colors32  = colors;
            mesh.triangles = triangles;
            mesh.uv        = uvs;
            return mesh;
        }

        [MenuItem("Voyage / Generate simple quad")]
        public static void ShowWindow()
        {
            GetWindow(typeof(QuadGenerator), false, "Generate Square");
        }

        

        private void OnGUI()
        {
            serialO.Update();

            EditorGUILayout.PropertyField(meshNameSerialized);

            EditorGUILayout.PropertyField(pointsSerialized);
            EditorGUILayout.PropertyField(uvsSerialized);

            serialO.ApplyModifiedProperties();

            if (meshName == null || meshName == "") return;

            if (GUILayout.Button("Generate mesh"))
            {
                
                
                AssetDatabase.CreateAsset(GenerateSquare(), "Assets/" + meshName + ".mesh");
            }
            
            
        }
    }
}
#endif