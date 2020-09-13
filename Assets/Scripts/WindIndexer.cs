using UnityEngine;

namespace Windy
{
    public class WindIndexer : MonoBehaviour
    {
        #region Constants

        private const string cWindIndexPropertyName = "_WindIndex";

        #endregion

        #region Fields

        [SerializeField] private SpriteRenderer _SpriteRenderer;

        private static readonly int sWindIndexPropertyID;

        #endregion

        static WindIndexer()
        {
            sWindIndexPropertyID = Shader.PropertyToID(name: cWindIndexPropertyName);
        }

        protected void Awake()
        {
            if (_SpriteRenderer != default)
            {
                MaterialPropertyBlock propertyBlock = new MaterialPropertyBlock();
                propertyBlock.SetInt(
                    nameID: sWindIndexPropertyID,
                    value: Random.Range(min: 0, max: WindManager.cBufferLength - 1));

                _SpriteRenderer.SetPropertyBlock(properties: propertyBlock);
            }
        }
    }
}