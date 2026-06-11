//
//  CandleChartViewController.swift
//  xWallet
//
//  Created by Xueliang Zhu on 20/3/26.
//

import UIKit
import MetalKit


class CandleChartViewController: UIViewController {

    // MARK: - Metal 核心对象（创建一次，整个生命周期复用）

    /// GPU 句柄 — 所有 Metal 对象都从它创建
    private var device: MTLDevice!

    /// 命令队列 — 向 GPU 提交工作的串行队列
    private var commandQueue: MTLCommandQueue!

    /// Metal 渲染宿主 View — 内部持有 CAMetalLayer，以屏幕刷新率驱动 draw(in:)
    private var mtkView: MTKView!
    
    private var pipelineState: MTLRenderPipelineState!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMetal()
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = commandQueue

        mtkView = MTKView(frame: view.bounds, device: device)
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1.0)
        
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.delegate = self

        view.addSubview(mtkView)

        // 创建 shader library 和 pipeline
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create default Metal library")
        }

        guard let vertexFunction = library.makeFunction(name: "candle_vertex") else {
            fatalError("Failed to find candle_vertex")
        }

        guard let fragmentFunction = library.makeFunction(name: "candle_fragment") else {
            fatalError("Failed to find candle_fragment")
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
}

// MARK: - MTKViewDelegate

extension CandleChartViewController: MTKViewDelegate {

    /// 视图大小变化时调用（旋转、分屏等）
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // L0 暂不处理，后续 L4 会在这里更新投影矩阵
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        ) else { return }

        // 告诉 GPU 使用哪条“生产线”
        encoder.setRenderPipelineState(pipelineState)

        // 一根绿色 K 线实体（先不画上下影线）
        // 用两个三角形拼一个矩形
        let positions: [SIMD2<Float>] = [
            SIMD2(-0.1,  0.5),   // triangle 1
            SIMD2(-0.1, -0.2),
            SIMD2( 0.1, -0.2),

            SIMD2(-0.1,  0.5),   // triangle 2
            SIMD2( 0.1, -0.2),
            SIMD2( 0.1,  0.5)
        ]

        let green = SIMD4<Float>(0.2, 0.9, 0.4, 1.0)
        let colors: [SIMD4<Float>] = Array(repeating: green, count: 6)

        // 把 Swift 数组交给 GPU
        encoder.setVertexBytes(
            positions,
            length: MemoryLayout<SIMD2<Float>>.stride * positions.count,
            index: 0
        )

        encoder.setVertexBytes(
            colors,
            length: MemoryLayout<SIMD4<Float>>.stride * colors.count,
            index: 1
        )

        // 画 6 个顶点，组成两个三角形
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
