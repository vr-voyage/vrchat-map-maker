#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using UdonSharp;
using System.Collections.Generic;

namespace Myy
{
    public class ColliderGridGenerator : EditorWindow
    {
        SerializedObject serialO;
        SerializedProperty gameObjectSerialized;
        
        public GameObject gameObject;
        public UnityEngine.Object saveDir;
        private string assetsDir;

        private void OnEnable()
        {
            assetsDir = Application.dataPath;
            serialO = new SerializedObject(this);
            gameObjectSerialized = serialO.FindProperty("gameObject");
            
            saveDir = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>("Assets");
        }

        [MenuItem("Voyage / Setup Collider Grid")]
        public static void ShowWindow()
        {
            GetWindow(typeof(ColliderGridGenerator), false, "Collider Grid Generator");
        }

        private void OnGUI()
        {
            bool everythingOK = true;
            serialO.Update();

            EditorGUILayout.PropertyField(gameObjectSerialized, true);
            serialO.ApplyModifiedProperties();

            if (gameObject == null) everythingOK = false;
            if (!everythingOK) return;

            float start = -0.35f;
            float end   = 0.35f;
            float size  = 0.1f;
            if (GUILayout.Button("Add colliders"))
            {
                foreach (BoxCollider collider in gameObject.GetComponents<BoxCollider>())
                {
                    DestroyImmediate(collider);
                }

                /*List<BoxCollider> colliders = new List<BoxCollider>(64);
                for (float xpos = start; xpos <= end; xpos += size)
                {
                    for (float ypos = start; ypos <= end; ypos += size)
                    {
                        BoxCollider collider = gameObject.AddComponent<BoxCollider>();
                        collider.size = new Vector3(size, size, 0.01f);
                        collider.center = new Vector3(xpos, ypos, 0f);
                        collider.isTrigger = true;
                        colliders.Add(collider);
                    }
                }*/

            }
        }


    }
}
#endif