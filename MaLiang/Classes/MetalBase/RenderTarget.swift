//
//  RenderTarget.swift
//  MaLiang
//
//  Created by Harley-xk on 2019/4/15.
//

import UIKit
import Foundation
import Metal
import simd

/// a target for any thing that can be render on
open class RenderTarget {
    
    /// texture to render on
    public private(set) var texture: MTLTexture?
    
    /// the scale level of view, all things scales
    open var scale: CGFloat = 1 {
        didSet {
            updateTransformBuffer()
        }
    }
    
    /// the zoom level of render target, only scale render target
    open var zoom: CGFloat = 1

    /// the offset of render target with zoomed size
    open var contentOffset: CGPoint = .zero {
        didSet {
            updateTransformBuffer()
        }
    }
    
    /// create with texture and device
    public init(size: CGSize, pixelFormat: MTLPixelFormat, device: MTLDevice?) {
        
        self.drawableSize = size
        self.pixelFormat = pixelFormat
        self.device = device
        self.texture = makeEmptyTexture()
        self.commandQueue = device?.makeCommandQueue()
        
        renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = renderPassDescriptor?.colorAttachments[0]
        attachment?.texture = texture
        attachment?.loadAction = .load
        attachment?.storeAction = .store
        
        updateBuffer(with: size)
    }
    
    /// clear the contents of texture
    open func clear() {
        texture = makeEmptyTexture()
        renderPassDescriptor?.colorAttachments[0].texture = texture
        commitCommands()
    }
    
    internal var pixelFormat: MTLPixelFormat = .bgra8Unorm
    internal var drawableSize: CGSize
    internal var uniform_buffer: MTLBuffer!
    internal var transform_buffer: MTLBuffer!
    internal var renderPassDescriptor: MTLRenderPassDescriptor?
    internal var commandBuffer: MTLCommandBuffer?
    internal var commandQueue: MTLCommandQueue?
    internal var device: MTLDevice?
    
    internal func updateBuffer(with size: CGSize) {
        self.drawableSize = size
        let metrix = Matrix.identity
        let zoomUniform = 2 * Float(zoom / scale )
        metrix.scaling(x: zoomUniform  / Float(size.width), y: -zoomUniform / Float(size.height), z: 1)
        metrix.translation(x: -1, y: 1, z: 0)
        uniform_buffer = device?.makeBuffer(bytes: metrix.m, length: MemoryLayout<Float>.size * 16, options: [])
        
        updateTransformBuffer()
    }
    
    internal func updateTransformBuffer() {
        let scaleFactor = UIScreen.main.nativeScale
        var transform = ScrollingTransform(offset: contentOffset * scaleFactor, scale: scale)
        transform_buffer = device?.makeBuffer(bytes: &transform, length: MemoryLayout<ScrollingTransform>.stride, options: [])
    }
    
    internal func prepareForDraw() {
        if commandBuffer == nil {
            commandBuffer = commandQueue?.makeCommandBuffer()
        }
    }

    internal func makeCommandEncoder() -> MTLRenderCommandEncoder? {
        guard let commandBuffer = commandBuffer, let rpd = renderPassDescriptor else {
            return nil
        }
        return commandBuffer.makeRenderCommandEncoder(descriptor: rpd)
    }
    
    internal func commitCommands() {
        commandBuffer?.commit()
        commandBuffer = nil
    }
    
    // make empty testure
//    internal func makeEmptyTexture() -> MTLTexture? {
//        guard drawableSize.width * drawableSize.height > 0 else {
//            return nil
//        }
//        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
//                                                                         width: Int(drawableSize.width),
//                                                                         height: Int(drawableSize.height),
//                                                                         mipmapped: false)
//        textureDescriptor.usage = [.renderTarget, .shaderRead]
//        let texture = device?.makeTexture(descriptor: textureDescriptor)
//        texture?.clear()
//        return texture
//    }
    
    internal func makeEmptyTexture() -> MTLTexture? {
        // Kiểm tra device
        guard let device = device else {
            print("Lỗi: Metal device không khả dụng")
            return nil
        }
        
        // Kiểm tra kích thước hợp lệ
        let width = Int(drawableSize.width)
        let height = Int(drawableSize.height)
        guard width > 0, height > 0 else {
            print("Lỗi: Kích thước không hợp lệ - width: \(width), height: \(height)")
            return nil
        }
        
        // Kiểm tra giới hạn thiết bị (tuỳ chọn)
        let maxSize = GL_MAX_TEXTURE_SIZE // Giới hạn tối đa của nhiều thiết bị Metal
        guard width <= maxSize, height <= maxSize else {
            print("Lỗi: Kích thước vượt quá giới hạn - width: \(width), height: \(height)")
            return nil
        }
        
        // Tạo descriptor
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        
        // Tạo texture
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            print("Lỗi: Không thể tạo texture với descriptor - pixelFormat: \(pixelFormat)")
            return nil
        }
        
        // Xóa texture (nếu cần)
        texture.clear() // Đảm bảo hàm clear() không gây lỗi
        
        return texture
    }
    
}
