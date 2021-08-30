import PlaygroundSupport
import MetalKit

//******************************* STAGE 1: INITIALIZE METAL *******************************
guard let device = MTLCreateSystemDefaultDevice() else{
    fatalError("GPU is not supported!")
}
let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)


//******************************* STAGE 2: LOAD A MODEL *******************************
// allocate memory for the mesh data
let allocator = MTKMeshBufferAllocator(device: device)
//create the object that contains all info about the vertices in the mesh
let mdlMesh = MDLMesh(sphereWithExtent: [0.76, 0.75, 0.75], segments: [100,100], inwardNormals: false, geometryType: .triangles, allocator: allocator)
//ModelI/O mesh is converted to a MetalKit mesh
let mesh = try MTKMesh(mesh: mdlMesh, device: device)

//******************************* STAGE 3: SET UP PIPELINE *******************************

// Each frame contains instructions for the GPU. These commands are packaged in a "render command encoder".
// Command buffers organize these command encoders and a command queue organizes these buffers.

// [COMMAND QUEUE] ---org.---> [COMMAND BUFFER] ------> [Render pass descriptor ]---org.---> [COMMAND ENCODERS] (lightweight objects that are created at every frame). COMMAND ENCODERS ARE WHAT ULTIMATELY TALK TO THE GPU
// They point to objects that are created once when the app starts like shaders.

guard let commandQueue = device.makeCommandQueue() else{
    fatalError("Could not create command queue")
}
// "Shaders" - Small programs that run on the GPU

let shader = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct VertexIn {
        float4 position [[ attribute(0) ]];
    };
    
    vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
        return vertex_in.position;
    }
    
    fragment float4 fragment_main(){
        return float4(1, 0, 0, 1);
    }
"""

// Now, we set up a metal library containing the two functions vertex_main (manipulating vertex info.)and fragment_main(mainpulating
// color info.)

let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")


//  In Metal, a pipeline state signals to the GPU that nothing will change until the state changes.
// A pipeline stores shit like pixel format, render with depth etc.

let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
pipelineDescriptor.vertexFunction = vertexFunction
pipelineDescriptor.fragmentFunction = fragmentFunction
pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

// Now that we've created the pipeline, we need to asign it a state
let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

//******************************* STAGE 4: RENDER *******************************
guard let commandBuffer = commandQueue.makeCommandBuffer(),
let renderPassDescriptor = view.currentRenderPassDescriptor,
let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
else { fatalError() }

renderEncoder.setRenderPipelineState(pipelineState)
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

guard let submesh = mesh.submeshes.first else{
    fatalError()
}

renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)

renderEncoder.endEncoding() // There are no more draw calls
guard let drawable = view.currentDrawable else{
    fatalError()
}

commandBuffer.present(drawable)
commandBuffer.commit() //“Ask the command buffer to present the MTKView’s drawable and commit to the GPU.”
PlaygroundPage.current.liveView = view

