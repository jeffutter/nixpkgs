del(.devDependencies)
| .dependencies += (.peerDependencies | {react, "react-dom"})
| del(.peerDependencies.react, .peerDependencies."react-dom")
