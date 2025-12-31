/**
 * Error view component with retry option.
 */
@Component
export struct ErrorView {
  @Prop message: string = 'An error occurred';
  @Prop showRetry: boolean = true;
  onRetry: () => void = () => {};

  build() {
    Column() {
      // Error icon
      Image($r('sys.media.ohos_ic_public_fail'))
        .width(64)
        .height(64)
        .fillColor('#DC2626')

      Text('Oops!')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .margin({ top: 24 })

      Text(this.message)
        .fontSize(14)
        .fontColor('#6B7280')
        .textAlign(TextAlign.Center)
        .margin({ top: 8, left: 32, right: 32 })

      if (this.showRetry) {
        Button('Retry')
          .type(ButtonType.Capsule)
          .backgroundColor('#7C3AED')
          .fontColor(Color.White)
          .fontSize(16)
          .padding({ left: 32, right: 32, top: 12, bottom: 12 })
          .margin({ top: 24 })
          .onClick(() => this.onRetry())
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F3FF')
  }
}
