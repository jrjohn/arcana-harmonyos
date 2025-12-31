/**
 * Loading indicator component with optional message.
 */
@Component
export struct LoadingView {
  @Prop message: string = 'Loading...';

  build() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#7C3AED')

      Text(this.message)
        .fontSize(14)
        .fontColor('#6B7280')
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F3FF')
  }
}

/**
 * Small inline loading indicator.
 */
@Component
export struct InlineLoading {
  build() {
    Row() {
      LoadingProgress()
        .width(24)
        .height(24)
        .color('#7C3AED')

      Text('Loading more...')
        .fontSize(14)
        .fontColor('#6B7280')
        .margin({ left: 8 })
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
  }
}
