/**
 * Loading indicator component with optional message and localization support.
 */
@Component
export struct LoadingView {
  @Prop message: string = '';
  messageResource?: Resource;

  build() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#7C3AED')

      if (this.messageResource) {
        Text(this.messageResource)
          .fontSize(14)
          .fontColor('#6B7280')
          .margin({ top: 16 })
      } else if (this.message.length > 0) {
        Text(this.message)
          .fontSize(14)
          .fontColor('#6B7280')
          .margin({ top: 16 })
      } else {
        Text($r('app.string.loading'))
          .fontSize(14)
          .fontColor('#6B7280')
          .margin({ top: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F3FF')
  }
}

/**
 * Small inline loading indicator with localization support.
 */
@Component
export struct InlineLoading {
  build() {
    Row() {
      LoadingProgress()
        .width(24)
        .height(24)
        .color('#7C3AED')

      Text($r('app.string.loading'))
        .fontSize(14)
        .fontColor('#6B7280')
        .margin({ left: 8 })
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
  }
}
