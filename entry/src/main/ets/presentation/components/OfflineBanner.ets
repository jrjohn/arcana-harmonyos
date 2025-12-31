/**
 * Offline mode banner component.
 */
@Component
export struct OfflineBanner {
  @Prop pendingSyncCount: number = 0;

  build() {
    Row() {
      Text('⚠')
        .fontSize(16)
        .fontColor('#92400E')

      Column() {
        Text('Offline Mode')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#92400E')

        if (this.pendingSyncCount > 0) {
          Text(`${this.pendingSyncCount} change${this.pendingSyncCount > 1 ? 's' : ''} pending sync`)
            .fontSize(12)
            .fontColor('#B45309')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FEF3C7')
  }
}

/**
 * Syncing indicator banner.
 */
@Component
export struct SyncingBanner {
  build() {
    Row() {
      LoadingProgress()
        .width(20)
        .height(20)
        .color('#7C3AED')

      Text('Syncing changes...')
        .fontSize(14)
        .fontColor('#5B21B6')
        .margin({ left: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#EDE9FE')
  }
}
