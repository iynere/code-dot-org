import React from 'react';
import {shallow} from 'enzyme';
import sinon from 'sinon';
import {assert, expect} from '../../../util/configuredChai';
import {sections} from './fakeSectionUtils';
import TeacherHomepage from '@cdo/apps/templates/studioHomepages/TeacherHomepage';
import TeacherSections from '@cdo/apps/templates/studioHomepages/TeacherSections';
import { announcement, courses, topCourse } from './homepagesTestData';

describe('TeacherHomepage', () => {
  let server;

  const successResponse = () => [
    200,
    {"Content-Type": "application/json"},
    JSON.stringify({})
  ];
  beforeEach(() => {
    server = sinon.fakeServer.create();
    server.respondWith('POST', '/dashboardapi/courses', successResponse());
    server.respondWith('POST', '/dashboardapi/sections', successResponse());
  });
  afterEach(() => server.restore());

  it('shows a non-extended Header Banner that says My Dashboard', () => {
    const wrapper = shallow(
      <TeacherHomepage
        announcements={[]}
        courses={[]}
        topCourse={topCourse}
        sections={[]}
        isRtl={false}
      />
    );
    const headerBanner = wrapper.find('HeaderBanner');
    assert.deepEqual(headerBanner.props(), {
      headingText: "My Dashboard",
      short: true
    });
  });

  it('references 2 ProtectedStatefulDivs', () => {
    const wrapper = shallow(
      <TeacherHomepage
        announcements={[]}
        courses={[]}
        topCourse={topCourse}
        sections={[]}
        isRtl={false}
      />
    );
    expect(wrapper.find('ProtectedStatefulDiv')).to.have.length(2);
  });

  it('shows an announcement', () => {
    const wrapper = shallow(
      <TeacherHomepage
        announcements={[announcement]}
        courses={[]}
        topCourse={topCourse}
        sections={[]}
        isRtl={false}
      />
    );
    const announcementContainer = wrapper.find('Notification');
    assert.deepEqual(announcementContainer.props(), {
      type: "bullhorn",
      notice: announcement.heading,
      details: announcement.description,
      dismissible: false,
      buttonText: announcement.buttonText,
      buttonLink: announcement.link,
      newWindow: true,
      analyticId: announcement.id,
      isRtl: false
    });
  });

  it('renders a TeacherSections component', () => {
    const wrapper = shallow(
      <TeacherHomepage
        announcements={[]}
        courses={[]}
        topCourse={topCourse}
        sections={sections}
        isRtl={false}
      />
    );
    expect(wrapper).to.containMatchingElement(
      <TeacherSections
        sections={sections}
        isRtl={false}
      />
    );
  });

  it('shows RecentCourses component', () => {
    const wrapper = shallow(
      <TeacherHomepage
        announcements={[]}
        topCourse={topCourse}
        courses={courses}
        sections={[]}
        isRtl={false}
      />
    );
    const recentCourses = wrapper.find('RecentCourses');
    assert.deepEqual(recentCourses.props(), {
      showAllCoursesLink: true,
      isTeacher: true,
      courses: courses,
      topCourse: topCourse,
      isRtl: false
    });
  });

  it('shows ProjectWidgetWithData component', () => {
    const wrapper = shallow(
      <TeacherHomepage
        announcements={[]}
        courses={courses}
        topCourse={topCourse}
        sections={[]}
        codeOrgUrlPrefix="http://localhost:3000/"
        isRtl={false}
      />
    );
    expect(wrapper.find('ProjectWidgetWithData').exists()).to.be.true;
  });
});
