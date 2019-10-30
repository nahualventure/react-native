//
//  Copyright © 2018-2019 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

#import <UIKit/UIKit.h>
#import <React/RCTComponent.h>

@import PSPDFKit;
@import PSPDFKitUI;

NS_ASSUME_NONNULL_BEGIN

@interface RCTPSPDFKitView: UIView

@property (nonatomic, readonly) PSPDFViewController *pdfController;
@property (nonatomic) BOOL hideNavigationBar;
@property (nonatomic, readonly) UIBarButtonItem *closeButton;
@property (nonatomic) BOOL disableDefaultActionForTappedAnnotations;
@property (nonatomic) BOOL disableAutomaticSaving;
@property (nonatomic, copy, nullable) NSString *annotationAuthorName;
@property (nonatomic, copy) RCTBubblingEventBlock onCloseButtonPressed;
@property (nonatomic, copy) RCTBubblingEventBlock onDocumentSaved;
@property (nonatomic, copy) RCTBubblingEventBlock onDocumentSaveFailed;
@property (nonatomic, copy) RCTBubblingEventBlock onAnnotationTapped;
@property (nonatomic, copy) RCTBubblingEventBlock onAnnotationsChanged;
@property (nonatomic, copy) RCTBubblingEventBlock onStateChanged;

/// Annotation Toolbar
- (BOOL)enterAnnotationCreationMode;
- (BOOL)exitCurrentlyActiveMode;
- (void)disableReplies;

/// Document
- (BOOL)saveCurrentDocument;

/// Anotations
- (NSDictionary<NSString *, NSArray<NSDictionary *> *> *)getAnnotations:(PSPDFPageIndex)pageIndex type:(PSPDFAnnotationType)type;
- (BOOL)addReplyWithUUID:(NSString *)annotationUUID contents:(id)contents;
- (BOOL)addReplyForAnnotationWithUUID: (NSString *)annotationUUID contents:(NSString *)contents;
- (BOOL)addAnnotation:(id)jsonAnnotation;
- (BOOL)removeAnnotationWithUUID:(NSString *)annotationUUID;
- (NSDictionary<NSString *, NSArray<NSDictionary *> *> *)getAllUnsavedAnnotations;
- (BOOL)addAnnotations:(NSString *)jsonAnnotations;

/// Forms
- (NSDictionary<NSString *, NSString *> *)getFormFieldValue:(NSString *)fullyQualifiedName;
- (void)setFormFieldValue:(NSString *)value fullyQualifiedName:(NSString *)fullyQualifiedName;

// Toolbar buttons customizations
- (void)setLeftBarButtonItems:(nullable NSArray <NSString *> *)items forViewMode:(nullable NSString *) viewMode animated:(BOOL)animated;
- (void)setRightBarButtonItems:(nullable NSArray <NSString *> *)items forViewMode:(nullable NSString *) viewMode animated:(BOOL)animated;
- (NSArray <NSString *> *)getLeftBarButtonItemsForViewMode:(NSString *)viewMode;
- (NSArray <NSString *> *)getRightBarButtonItemsForViewMode:(NSString *)viewMode;

@end

NS_ASSUME_NONNULL_END
