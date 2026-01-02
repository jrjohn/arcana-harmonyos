/**
 * Empty state view component with localization support.
 */
@Component
export struct EmptyView {
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop showAction: boolean = false;
  @Prop actionText: string = '';
  titleResource?: Resource;
  messageResource?: Resource;
  actionTextResource?: Resource;
  onAction: () => void = () => {};

  build() {
    Column() {
      // Empty icon
      Text('📋')
        .fontSize(64)

      // Title - use resource if provided
      if (this.titleResource) {
        Text(this.titleResource)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .margin({ top: 24 })
      } else if (this.title.length > 0) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .margin({ top: 24 })
      }

      // Message - use resource if provided
      if (this.messageResource) {
        Text(this.messageResource)
          .fontSize(14)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .margin({ top: 8, left: 32, right: 32 })
      } else if (this.message.length > 0) {
        Text(this.message)
          .fontSize(14)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .margin({ top: 8, left: 32, right: 32 })
      }

      // Action button - use resource if provided
      if (this.showAction) {
        if (this.actionTextResource) {
          Button(this.actionTextResource)
            .type(ButtonType.Capsule)
            .backgroundColor('#7C3AED')
            .fontColor(Color.White)
            .fontSize(16)
            .padding({ left: 32, right: 32, top: 12, bottom: 12 })
            .margin({ top: 24 })
            .onClick(() => this.onAction())
        } else {
          Button(this.actionText || 'Add')
            .type(ButtonType.Capsule)
            .backgroundColor('#7C3AED')
            .fontColor(Color.White)
            .fontSize(16)
            .padding({ left: 32, right: 32, top: 12, bottom: 12 })
            .margin({ top: 24 })
            .onClick(() => this.onAction())
        }
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F3FF')
  }
}
