import { User, UserFactory } from '../../domain/models/User';

/**
 * User card component for displaying user information in lists.
 */
@Component
export struct UserCard {
  @Prop user: User;
  @Prop showSyncStatus: boolean = false;
  @Prop isPendingSync: boolean = false;
  onTap: () => void = () => {};
  onLongPress: () => void = () => {};

  build() {
    Row() {
      // Avatar
      Stack({ alignContent: Alignment.Center }) {
        if (this.user.avatar && this.user.avatar.length > 0) {
          Image(this.user.avatar)
            .width(56)
            .height(56)
            .borderRadius(28)
            .objectFit(ImageFit.Cover)
        } else {
          // Default avatar with initials
          Text(UserFactory.getInitials(this.user))
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }

        // Sync status indicator
        if (this.showSyncStatus && this.isPendingSync) {
          Circle()
            .width(12)
            .height(12)
            .fill('#FCD34D')
            .stroke(Color.White)
            .strokeWidth(2)
            .position({ x: 44, y: 0 })
        }
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor('#7C3AED')

      // User info
      Column() {
        Text(UserFactory.getFullName(this.user))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.user.email)
          .fontSize(14)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 16 })

      // Arrow indicator
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(20)
        .height(20)
        .fillColor('#9CA3AF')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: 'rgba(0, 0, 0, 0.05)',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => this.onTap())
    .gesture(
      LongPressGesture()
        .onAction(() => this.onLongPress())
    )
  }
}
